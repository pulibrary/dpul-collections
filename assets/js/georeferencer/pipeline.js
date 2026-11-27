// The whole per-canvas georeferencing, headless, on the contributor's machine: border, parts,
// OCR (whole sheet + tiles), street names, printed scale, then per part the GPU search, snap,
// corridor refinement and the acceptance check. Worker-safe (no DOM). Mirrors the server's
// Georef.georeference_canvas up to the per-part fit; the server's later atlas-wide passes
// (slide, neighbour, rescue, consistency) are not here yet.
import { fromImage, readPage, loadOcr } from "./ocr";
import { neatline, splitParts, loadCv } from "./sheetgeom";
import { toToken, sheetLabels, tileStarts, cutByTileEdge, dedupeTiles, gazetteer, TILE, matchName, normalize, suffixOnly } from "./labels";
import { prepareInk, partSheet, samplePoints, targetedLabels, pointInPoly, fwd, toAB, fromAB, labelStatus, nearestSeg, LABEL_TOL } from "./engine";
import { gpuDevice, makeGpu } from "./gpu";
import { findPlacement, distinctLabels, contrast } from "./search";

const NOMINAL_DPI = 395;
const STANDARD_FT = [50, 60, 100, 200, 300, 400, 500, 600, 800, 1000];
const SCAN_DPI = [355, 427];

// Georef.scale_consistent? / scale_ok?: the fit's scale matches the printed one at 355..427 dpi
// (any standard Sanborn scale when none was read), or it is a key map (>= 4x the printed scale,
// a standard scale, >= 8 names on their streets)
const consistent = (s, ft) => (ft ? ((d) => d >= SCAN_DPI[0] && d <= SCAN_DPI[1])((ft * 0.3048) / s) : STANDARD_FT.some((f) => consistent(s, f)));
export const scaleOk = (s, ft, hits) =>
  consistent(s, ft) || (!!ft && hits >= 8 && (s * NOMINAL_DPI) / 0.3048 >= 4 * ft && consistent(s, null));

// Georef.crossing_streets?: the modern streets under the names that landed must cross (> 30 deg)
function crossingStreets(T, labs) {
  const dirs = [];
  for (const l of labelStatus(T, labs)) {
    if (l.d > LABEL_TOL) continue;
    const n = nearestSeg(l.segs, l.x, l.y);
    dirs.push(Math.atan2(n.ey, n.ex));
  }
  const between = (a, b) => { let d = Math.abs(a - b) % Math.PI; return (Math.min(d, Math.PI - d) * 180) / Math.PI; };
  return dirs.some((a) => dirs.some((b) => between(a, b) > 30));
}

async function fetchImage(service, size, region = "full") {
  const u = `/georeferencer/image?service=${encodeURIComponent(service)}&size=${encodeURIComponent(size)}&region=${region}`;
  const r = await fetch(u);
  if (!r.ok) throw new Error(`image ${r.status}`);
  return fromImage(await createImageBitmap(await r.blob()));
}

/** the atlas's town, fetched once: name matcher, label targets, corridor points */
const towns = new Map();
export function loadTown(url) {
  if (!towns.has(url))
    towns.set(url, fetch(url).then((r) => r.json()).then((o) => {
      const targets = {}, kinds = {};
      for (const [k, g] of Object.entries(o.groups)) { targets[k] = g.segs; kinds[k] = g.kind; }
      return { gaz: gazetteer(o.groups), targets, kinds, pts: samplePoints(o.lines), lines: o.lines, crossings: o.crossings || [] };
    }));
  return towns.get(url);
}

// Georef.printed_scales / printed_scale: statements as feet per inch, one vote per statement
const SCALE_RE = /s?cale[\s,.:;]*([0-9IOloZz]{2,4})\s*f/i;
export function printedScales(tokens) {
  const out = [];
  for (const t of tokens) {
    const m = SCALE_RE.exec(t.text);
    if (!m) continue;
    const d = m[1].replace(/[Il]/g, "1").replace(/[Oo]/g, "0").replace(/[Zz]/g, "2");
    if (/^\d+$/.test(d)) out.push({ ft: parseInt(d, 10), px: t.center });
  }
  return out;
}
export function printedScale(scales) {
  if (!scales.length) return null;
  let sts = [];
  for (const s of scales) {
    const near = sts.filter((st) => st.some((o) => Math.hypot(o.px[0] - s.px[0], o.px[1] - s.px[1]) < 300));
    sts = [[s, ...near.flat()], ...sts.filter((st) => !near.includes(st))];
  }
  const votes = new Map();
  for (const st of sts) {
    const top = Math.min(...st.map((o) => o.px[1]));
    for (const ft of new Set(st.map((o) => o.ft))) votes.set(ft, (votes.get(ft) || []).concat([top]));
  }
  let best = null;
  for (const [ft, tops] of votes) {
    const k = [tops.length, -Math.min(...tops)];
    if (!best || k[0] > best.k[0] || (k[0] === best.k[0] && k[1] > best.k[1])) best = { ft, k };
  }
  return best.ft;
}

/** the scales a part may have: its printed scale at 355..427 dpi (the server's gate), else any
 *  of the usual Sanborn scales (50..200 ft to the inch) */
function scaleRange(ft) {
  if (ft) return { smin: (ft * 0.3048) / 427, smax: (ft * 0.3048) / 355, usual: [(ft * 0.3048) / NOMINAL_DPI] };
  return anyScale();
}
const anyScale = () => {
  return { smin: (40 * 0.3048) / 427, smax: (220 * 0.3048) / 355, usual: [50, 100, 200].map((f) => (f * 0.3048) / NOMINAL_DPI) };
};
// a key map under a sheet-scale statement: 4x the printed scale and up
const keyMapScale = (ft) => ({ smin: (4 * ft * 0.3048) / 427, smax: (1000 * 0.3048) / 355, usual: STANDARD_FT.filter((f) => f >= 4 * ft).map((f) => (f * 0.3048) / NOMINAL_DPI) });

let gpuDev = null;

// Osm.with_aliases: each learned rename (printed key -> modern key) gets the modern street's segments
function withAliases(town, renames) {
  const entries = Object.entries(renames || {}).filter(([a, k]) => a !== k && town.targets[k]);
  if (!entries.length) return town;
  const targets = { ...town.targets }, kinds = { ...town.kinds };
  for (const [a, k] of entries) { targets[a] = town.targets[k]; kinds[a] = town.kinds[k]; }
  // the alias meets what its street meets
  const crossings = town.crossings.slice();
  for (const [a, k] of entries)
    for (const [k1, k2, x, y] of town.crossings) {
      const other = k1 === k ? k2 : k2 === k ? k1 : null;
      if (other && other !== a) crossings.push([...[a, other].sort(), x, y]);
    }
  return { ...town, targets, kinds, crossings, gaz: gazetteer(targets) };
}

// Georef.Renames.observe: street-name sized words on a fitted part, each with the modern street
// whose centreline it sits on, running its way (votes for learning renames)
function observeRenames(T, mask, tokens, town, exclude) {
  const out = [];
  const between = (a, b) => { const d = Math.abs(a - b) % Math.PI; return (Math.min(d, Math.PI - d) * 180) / Math.PI; };
  for (const t of tokens) {
    if (t.score < 0.8 || !(t.height >= 100) || t.angle == null || !pointInPoly(t.center[0], t.center[1], mask)) continue;
    if (t.text.replace(/[^\p{L}]/gu, "").length < 3 || /,|\.\./.test(t.text)) continue;
    const key = matchName(town.gaz.keys, town.gaz.keySet, t.text) || normalize(t.text);
    if (!key || suffixOnly(key) || exclude.includes(key)) continue;
    const w = fwd(T, t.center[0], t.center[1]), w2 = fwd(T, t.center[0] + 100 * Math.cos(t.angle), t.center[1] + 100 * Math.sin(t.angle));
    const dir = Math.atan2(w2[1] - w[1], w2[0] - w[0]);
    let best = null;
    for (const [k, segs] of Object.entries(town.targets)) {
      if (town.kinds[k] !== "street") continue;
      for (let i = 0; i + 3 < segs.length; i += 4) {
        const ax = segs[i], ay = segs[i + 1], dx = segs[i + 2] - ax, dy = segs[i + 3] - ay, L2 = Math.max(dx * dx + dy * dy, 1e-9);
        const u = Math.min(1, Math.max(0, ((w[0] - ax) * dx + (w[1] - ay) * dy) / L2));
        const d = Math.hypot(w[0] - ax - u * dx, w[1] - ay - u * dy);
        if (d <= LABEL_TOL && between(dir, Math.atan2(dy, dx)) <= 20 && (!best || d < best.d)) best = { d, k };
      }
    }
    if (best) out.push([key, best.k]);
  }
  return out;
}

const OCR_VERSION = "ocr-v1";
function idb() {
  return new Promise((resolve) => {
    try {
      const rq = indexedDB.open("georef", 1);
      rq.onupgradeneeded = () => rq.result.createObjectStore("ocr");
      rq.onsuccess = () => resolve(rq.result);
      rq.onerror = () => resolve(null);
    } catch { resolve(null); }
  });
}
async function cacheGet(key) {
  const db = await idb();
  if (!db) return null;
  return new Promise((resolve) => {
    try { const r = db.transaction("ocr").objectStore("ocr").get(key); r.onsuccess = () => resolve(r.result || null); r.onerror = () => resolve(null); }
    catch { resolve(null); }
  });
}
async function cachePut(key, value) {
  const db = await idb();
  if (!db) return;
  try { db.transaction("ocr", "readwrite").objectStore("ocr").put(value, key); } catch { /* full or blocked: fine */ }
}

/** job: {canvas: {id, label, service, width, height}, town: osm url, exclude_keys}
 *  -> {parts: [...], timings, counts} */
export async function processCanvas(job, onStep = () => {}) {
  const t = { start: performance.now() }, lap = (k) => (t[k] = Math.round(performance.now() - t.start));
  const c = job.canvas;
  onStep("loading models and the town");
  const [town0] = await Promise.all([loadTown(job.town), loadOcr(), loadCv()]);
  const town = withAliases(town0, job.renames);
  gpuDev ||= await gpuDevice();
  lap("loaded");

  onStep("finding the border and parts");
  const neat = await neatline(await fetchImage(c.service, "!1536,1536"), c.width, c.height);
  const parts = await splitParts(await fetchImage(c.service, "!2000,2000"), c.width, c.height, neat.map(([x, y]) => [Math.round(x), Math.round(y)]));
  lap("parts");
  onStep("found the sheet's parts", { parts });

  const cacheKey = `${c.id}|${OCR_VERSION}`;
  let { wholeTokens, tileTokens, nTiles } = (await cacheGet(cacheKey)) || {};
  if (!wholeTokens) {
    onStep("reading the sheet");
    const whole = await fetchImage(c.service, "!3000,3000");
    const k = c.width / whole.w;
    wholeTokens = (await readPage(whole)).map((it) => toToken(it, k));
    lap("ocr_whole");
    const regions = [];
    for (const x of tileStarts(c.width)) for (const y of tileStarts(c.height))
      regions.push([x, y, Math.min(TILE, c.width - x), Math.min(TILE, c.height - y)]);
    tileTokens = [];
    for (let i = 0; i < regions.length; i++) {
      onStep(`reading tile ${i + 1} of ${regions.length}`);
      const [x0, y0, w, h] = regions[i];
      const img = await fetchImage(c.service, "!1536,1536", `${x0},${y0},${w},${h}`);
      tileTokens = tileTokens.concat((await readPage(img)).map((it) => toToken(it, w / img.w, x0, y0))
        .filter((tk) => !cutByTileEdge(tk, regions[i], c.width, c.height)));
    }
    tileTokens = dedupeTiles(tileTokens);
    nTiles = regions.length;
    await cachePut(cacheKey, { wholeTokens, tileTokens, nTiles });
  }
  lap("ocr_tiles");

  const labels = sheetLabels(wholeTokens, tileTokens, town.gaz, job.exclude_keys || []);
  const scales = printedScales(wholeTokens.concat(tileTokens));
  onStep(`read ${labels.length} street names`, { parts, labels: labels.map((l) => ({ px: l.px, name: l.name })) });

  onStep("preparing the street corridors");
  const ink = await prepareInk(await fetchImage(c.service, "3000,"), c.width);
  lap("ink");

  const out = [], votes = [];
  for (let p = 0; p < parts.length; p++) {
    const mask = parts[p], inside = (q) => pointInPoly(q[0], q[1], mask);
    const partLabels = labels.filter((l) => inside(l.px));
    const ft = printedScale(scales.filter((s) => inside(s.px)));
    const range = scaleRange(ft);
    const labs = distinctLabels(targetedLabels(partLabels.map((l) => ({ ...l, px: l.px })), town.targets));
    const res = { part: p + 1, mask, printed_scale_ft: ft, labels: partLabels, status: "failed" };
    if (labs.length >= 2) {
      onStep(`fitting part ${p + 1} of ${parts.length}`);
      const sheet = partSheet(ink, mask);
      const gpu = await makeGpu(gpuDev, sheet, town.pts, labs);
      try {
        const needed = Math.max(3, Math.ceil(0.25 * partLabels.length));
        const gate = (r) => !r.error && r.hits >= needed && crossingStreets(r.T, labs) && scaleOk(r.T[0], ft, r.hits);
        const cmpT = (job.compare || [])[p] && fromAB(job.compare[p]);
        const seedTs = junctionPlacements(partLabels.filter((l) => town.targets[l.key]), town.crossings, c.width, c.height, range);
        let r = await findPlacement(gpu, sheet, labs, range, undefined, { near: cmpT && fwd(cmpT, sheet.centre[0], sheet.centre[1]), seedTs });
        // the server's key-map exception: an overview under the sheet's scale statement
        if (!gate(r) && ft && labs.length >= 8) {
          const k = await findPlacement(gpu, sheet, labs, keyMapScale(ft), undefined, { seedTs: junctionPlacements(partLabels.filter((l) => town.targets[l.key]), town.crossings, c.width, c.height, keyMapScale(ft)) });
          if (gate(k)) r = { ...k, keyMap: true };
        }
        if (!r.error) {
          // ok: the server's gates; a weak corridor peak is still kept but flagged for a look
          // (not for key maps: their streets are drawn too small for corridors)
          // or where the corridors say little (faint or wide-spaced streets) but the names clearly
          // win: the best placement elsewhere puts at least 2 fewer names on their streets
          const ok = gate(r) && (r.keyMap || r.contrast >= 0.05 || r.hits - r.rivalHits >= 2);
          Object.assign(res, {
            status: ok ? "ok" : "unsure", transform: toAB(r.T), label_hits: r.hits, needed, rival_hits: r.rivalHits,
            contrast: r.contrast, corridor: r.corridor, scale_m_per_px: r.T[0], candidates: r.nCand, key_map: !!r.keyMap, debug: job.compare ? r.debug : undefined,
          });
          if (r.keyMap) res.mask = keyMapMask(r.T, labs, mask);
          if (ok) votes.push(...observeRenames(r.T, res.mask, wholeTokens, town, job.exclude_keys || []));
        } else res.reason = r.error;
        const cmp = (job.compare || [])[p];
        if (cmp) {
          const T = fromAB(cmp);
          res.compare = { hits: labelStatus(T, labs).filter((l) => l.d <= LABEL_TOL).length, contrast: await contrast(gpu, sheet, T),
                          centre: fwd(T, sheet.centre[0], sheet.centre[1]).map(Math.round), on: labelStatus(T, labs).filter((l) => l.d <= LABEL_TOL).map((l) => l.key) };
        }
      } finally {
        gpu.destroy();
      }
    } else res.reason = "fewer than two street names";
    out.push(res);
  }
  lap("fit");
  return {
    parts: out, votes, neatline: neat, timings: t, round: job.round || 1,
    // the whole-sheet words (the server's consistency check reads sheet numbers off key maps)
    tokens: wholeTokens.map(({ text, score, quad }) => ({ text, score, quad: quad.map(([x, y]) => [Math.round(x), Math.round(y)]) })),
    counts: { tokens: wholeTokens.length, tile_tokens: tileTokens.length, labels: labels.length, tiles: nTiles },
    gpu: gpuDev.info,
  };
}

// Georef.label_junctions + Geometry.hypotheses: each street name marks a line on the sheet; two
// names of streets that cross in OSM meet at that crossing. Two such junctions fix a placement.
function junctionPlacements(labels, crossings, W, H, range) {
  const byKeys = new Map();
  for (const [k1, k2, x, y] of crossings) {
    const kk = `${k1}|${k2}`;
    if (!byKeys.has(kk)) byKeys.set(kk, []);
    byKeys.get(kk).push([x, y]);
  }
  const reach = 0.5 * Math.max(W, H), seeds = [], seen = new Set();
  const between = (a, b) => { const d = Math.abs(a - b) % Math.PI; return (Math.min(d, Math.PI - d) * 180) / Math.PI; };
  for (const a of labels) for (const b of labels) {
    if (!(a.key < b.key) || a.angle == null || b.angle == null) continue;
    const xys = byKeys.get(`${a.key}|${b.key}`);
    if (!xys || between(a.angle, b.angle) <= 25) continue;
    const d1 = [Math.cos(a.angle), Math.sin(a.angle)], d2 = [Math.cos(b.angle), Math.sin(b.angle)];
    const den = d1[0] * d2[1] - d1[1] * d2[0];
    if (Math.abs(den) < 1e-6) continue;
    const t = ((b.px[0] - a.px[0]) * d2[1] - (b.px[1] - a.px[1]) * d2[0]) / den;
    const px = [a.px[0] + t * d1[0], a.px[1] + t * d1[1]];
    if (px[0] < 0 || px[1] < 0 || px[0] > W || px[1] > H) continue;
    if (Math.hypot(px[0] - a.px[0], px[1] - a.px[1]) >= reach || Math.hypot(px[0] - b.px[0], px[1] - b.px[1]) >= reach) continue;
    const id = `${a.key}|${b.key}|${Math.round(px[0] / 300)}|${Math.round(px[1] / 300)}`;
    if (seen.has(id)) continue;
    seen.add(id);
    for (const xy of xys) seeds.push({ keys: `${a.key}|${b.key}`, px, xy });
  }
  const Ts = [];
  for (let i = 0; i < seeds.length && Ts.length < 20000; i++)
    for (let j = i + 1; j < seeds.length; j++) {
      const p = seeds[i], q = seeds[j];
      if (p.keys === q.keys || Math.hypot(p.px[0] - q.px[0], p.px[1] - q.px[1]) <= 100) continue;
      const dcx = q.px[0] - p.px[0], dcy = -(q.px[1] - p.px[1]), dwx = q.xy[0] - p.xy[0], dwy = q.xy[1] - p.xy[1];
      const s = Math.hypot(dwx, dwy) / Math.hypot(dcx, dcy);
      if (s < range.smin || s > range.smax) continue;
      const th = Math.atan2(dwy, dwx) - Math.atan2(dcy, dcx), [x0, y0] = fwd([s, th, 0, 0], p.px[0], p.px[1]);
      Ts.push([s, th, p.xy[0] - x0, p.xy[1] - y0]);
    }
  return Ts;
}

// Georef.key_map_mask: a key map fitted under a sheet statement keeps only the box around its
// labels on their streets, padded by 10 % of the part's size, within the part's box
function keyMapMask(T, labs, mask) {
  const on = labelStatus(T, labs).filter((l) => l.d <= LABEL_TOL);
  const xs = mask.map((p) => p[0]), ys = mask.map((p) => p[1]);
  const [X0, X1, Y0, Y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const px = 0.1 * (X1 - X0), py = 0.1 * (Y1 - Y0);
  const x0 = Math.max(X0, Math.min(...on.map((l) => l.u)) - px), x1 = Math.min(X1, Math.max(...on.map((l) => l.u)) + px);
  const y0 = Math.max(Y0, Math.min(...on.map((l) => l.v)) - py), y1 = Math.min(Y1, Math.max(...on.map((l) => l.v)) + py);
  return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
}
