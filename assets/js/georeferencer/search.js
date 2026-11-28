// Find where a map part sits, from its OCR'd street names alone, on the contributor's GPU:
// every pair of far-apart labels on two different streets, placed on every pair of points of
// those streets (5 m apart), gives a placement; the GPU counts how many of all the labels then
// land on their own streets. The best few are snapped (labels least squares) and ranked by
// label hits, then by the street-corridor score.
import { fwd, snap, labelStatus, sampleKey, gridCheck, nearestSeg, LABEL_TOL } from "./engine";

/** corridor contrast at which the printed streets count as lined up (the pipeline's ok check) */
export const CONTRAST_OK = 0.15;

const STEP = 5; // m between street samples
const BUDGET = 120e6; // candidate placements per search

export function scaleRange(input) {
  const ft = input.canvas.printed_scale_ft;
  // the scale gate: 355..427 dpi at the printed scale
  if (ft) return { smin: (ft * 0.3048) / 427, smax: (ft * 0.3048) / 355, usual: [(ft * 0.3048) / 395] };
  const s = input.scales.slice().sort((a, b) => a - b);
  if (!s.length) return { smin: 0.03, smax: 0.1 };
  const med = s[Math.floor(s.length / 2)];
  const usual = s.filter((x) => x < 2.5 * med); // key maps aside
  return { smin: 0.88 * usual[0], smax: 1.12 * usual[usual.length - 1], usual };
}

// one label per street name per neighbourhood (tiled OCR reads the same label twice)
export function distinctLabels(labs) {
  const out = [];
  for (const l of labs.slice().sort((a, b) => b.h - a.h))
    if (!out.some((o) => o.key === l.key && Math.hypot(o.u - l.u, o.v - l.v) < 300)) out.push(l);
  return out;
}

// labs: distinctLabels(targetedLabels(...)), the same list the GPU was given
export async function findPlacement(gpu, sheet, labs, range, onStep = () => {}, opts = {}) {
  const t0 = performance.now();
  if (new Set(labs.map((l) => l.key)).size < 2) return { error: "fewer than two street names to go on" };

  const sampByKey = new Map(), samp = [], labSamp = [];
  for (const l of labs) {
    if (!sampByKey.has(l.key)) {
      const s = sampleKey(l.segs, STEP);
      sampByKey.set(l.key, { start: samp.length / 2, count: s.length / 2 });
      samp.push(...s);
    }
    labSamp.push(sampByKey.get(l.key));
  }

  // pairs: different streets, long baselines first, at most 2 per street pair, within budget
  const diam = 2 * sheet.radius, cand = [];
  for (let i = 0; i < labs.length; i++)
    for (let j = i + 1; j < labs.length; j++) {
      const d = Math.hypot(labs[i].u - labs[j].u, labs[i].v - labs[j].v);
      if (labs[i].key !== labs[j].key && d >= 0.15 * diam) cand.push([i, j, d]);
    }
  cand.sort((a, b) => b[2] - a[2]);
  const perKeys = new Map(), pairs = [];
  let n = 0;
  for (const [i, j] of cand) {
    const k = [labs[i].key, labs[j].key].sort().join("|");
    if ((perKeys.get(k) || 0) >= 2) continue;
    const c = labSamp[i].count * labSamp[j].count;
    if (n + c > BUDGET) continue;
    perKeys.set(k, (perKeys.get(k) || 0) + 1); pairs.push([i, j]); n += c;
    if (pairs.length >= 400) break;
  }
  if (!pairs.length) return { error: "no usable pair of street names" };

  onStep(`trying ${(n / 1e6).toFixed(1)} million placements on your GPU`);
  const t1 = performance.now();
  const { best, layout, nCand } = await gpu.pairSearch(pairs, samp, labSamp, { ...range, tol: 12 });
  const msGpu = performance.now() - t1;

  const decode = (g) => {
    let lo = 0, hi = pairs.length - 1;
    while (lo < hi) { const m = (lo + hi + 1) >> 1; if (layout[4 * m + 2] <= g) lo = m; else hi = m - 1; }
    const i = layout[4 * lo], j = layout[4 * lo + 1], r = g - layout[4 * lo + 2], nB = layout[4 * lo + 3];
    const a = labSamp[i].start + Math.floor(r / nB), b = labSamp[j].start + (r % nB);
    const Li = labs[i], Lj = labs[j];
    const dcx = Lj.u - Li.u, dcy = -(Lj.v - Li.v), dwx = samp[2 * b] - samp[2 * a], dwy = samp[2 * b + 1] - samp[2 * a + 1];
    const s = Math.hypot(dwx, dwy) / Math.hypot(dcx, dcy), th = Math.atan2(dwy, dwx) - Math.atan2(dcy, dcx);
    const [x0, y0] = fwd([s, th, 0, 0], Li.u, Li.v);
    return [s, th, samp[2 * a] - x0, samp[2 * a + 1] - y0];
  };

  const top = [];
  best.forEach((e, w) => { if (e >> 8 >= 2) top.push({ hits: e >> 8, g: w * 256 + (e & 255) }); });
  top.sort((a, b) => b.hits - a.hits);

  onStep("snapping the best placements to their streets");
  const [cu, cv] = sheet.centre, all = labs;
  const hitsOf = (T) => labelStatus(T, all).filter((l) => l.d <= LABEL_TOL).length;
  // the scale prior: the atlas's usual scale nearest the candidate's (sheets share a scale class)
  const prior = (s) => (range.usual && range.usual.length ? range.usual.reduce((a, b) => (Math.abs(Math.log(b / s)) < Math.abs(Math.log(a / s)) ? b : a)) : s);
  const snapped = [];
  // With few names, tens of thousands of workgroups tie on names (parallel-street ladders): take
  // every one within a name of the best, one per 20 m / 3 deg / 2 % cell, and snap them all.
  const gpuMax = top.length ? top[0].hits : 0, cells = new Set(), distinct = [];
  for (const c of top) {
    if (c.hits < gpuMax - 1 || distinct.length >= 8000) break;
    const T0 = decode(c.g), w = fwd(T0, cu, cv);
    const cell = `${Math.round(w[0] / 20)},${Math.round(w[1] / 20)},${Math.round((T0[1] * 180) / Math.PI / 3)},${Math.round(Math.log(T0[0]) / 0.02)}`;
    if (cells.has(cell)) continue;
    cells.add(cell); distinct.push(T0);
  }
  // placements from junction seeds (rough fits from named crossings) join the search's
  let nSeed = 0;
  for (const T0 of opts.seedTs || []) {
    if (nSeed >= 6000) break;
    const w = fwd(T0, cu, cv);
    const cell = `${Math.round(w[0] / 20)},${Math.round(w[1] / 20)},${Math.round((T0[1] * 180) / Math.PI / 3)},${Math.round(Math.log(T0[0]) / 0.02)}`;
    if (cells.has(cell)) continue;
    cells.add(cell); distinct.push(T0); nSeed++;
  }
  for (const T0 of distinct) {
    // labels-only fit: matching radius tightened in steps, (almost) no scale prior
    let T = T0;
    for (const radius of [20, 12, 8]) T = snap(T, all, { radius, s0: T0[0], priorWeight: 5 }) || T;
    // with few names on few directions the fit can slide along the streets: never lose a name
    if (hitsOf(T) < hitsOf(T0)) T = T0;
    const ok = T[0] >= range.smin * 0.95 && T[0] <= range.smax * 1.05;
    if (ok) snapped.push({ T, hits: hitsOf(T), w: fwd(T, cu, cv) });
  }
  snapped.sort((a, b) => b.hits - a.hits);
  if (!snapped.length) return { error: "no placement put two street names on their streets", nCand, msGpu };
  // distinct placements (15 m apart) among those with the most names on their streets
  const maxHits = snapped[0].hits, pool = [];
  for (const c of snapped) {
    if (c.hits < maxHits - 2 || pool.length >= 4000) break;
    if (!pool.some((k) => Math.hypot(k.w[0] - c.w[0], k.w[1] - c.w[1]) < 15)) pool.push(c);
  }
  // rank by names on their streets, ties by the corridor contrast (a true fit is a peak of street-in-corridor fraction against nearby wrong placements)
  // contrast: a placement where the printed streets line up beats a ladder of parallel street
  // names that happen to land on parallel streets
  const whits = (T) => labelStatus(T, all).filter((l) => l.d <= LABEL_TOL).reduce((a, l) => a + (l.building || !l.h || l.h >= 90 ? 1 : l.h >= 80 ? 0.75 : 0.5), 0);
  const cs = await contrastBatch(gpu, sheet, pool.map((c) => c.T));
  pool.forEach((c, i) => { c.contrast = cs[i]; c.whits = whits(c.T); });
  // names on their streets, plus the corridor peak: 0.33 of contrast is worth one name (a
  // ladder of parallel names has none; a near miss of the right placement is refined below)
  const rank = (c) => c.hits + 3 * c.contrast;
  const byRank = (a, b) => rank(b) - rank(a);
  // the pick: a placement whose streets line up beats any that don't, however many names those
  // have (one more name landing on a parallel street outranked a true fit 580 m away)
  // the grid check (engine.gridCheck) when the town's street points are given (opts.pts)
  const gridOf = (T) => (opts.pts ? gridCheck(sheet, opts.pts, T) : null);
  // the pick: a placement that can be accepted beats any that can't, however many names those have.
  // Accepted: the pipeline's gates (opts.gate: enough names, names on crossing streets, scale), the
  // printed streets lining up, and the grid. (One more name on a parallel street outranked a true fit
  // 580 m away; four names all on parallel streets outranked four that cross, Salem sheet 3.)
  const passes = (c) => !opts.gate || opts.gate(c);
  const lines = (c) => c.contrast >= CONTRAST_OK && !c.grid?.bad && passes(c);
  const byPick = (a, b) => lines(b) - lines(a) || byRank(a, b);
  pool.sort(byRank);
  // refine the top three, plus the best two that could be accepted already
  const tops = [...pool.slice(0, 3), ...pool.slice(3).filter((c) => c.contrast >= CONTRAST_OK && passes(c)).slice(0, 2)];
  // a top placement turned off the grid (names in a cross turn freely about their centre) is also
  // tried turned onto it, about the names it has on their streets
  for (const c of pool.slice(0, 3)) {
    const g = gridOf(c.T);
    if (!g?.bad) continue;
    const on = labelStatus(c.T, all).filter((l) => l.d <= LABEL_TOL);
    const pu = on.length ? on.reduce((a, l) => a + l.u, 0) / on.length : cu, pv = on.length ? on.reduce((a, l) => a + l.v, 0) / on.length : cv;
    const th = c.T[1] - (g.delta * Math.PI) / 180, p = fwd(c.T, pu, pv), [x0, y0] = fwd([c.T[0], th, 0, 0], pu, pv);
    const T = [c.T[0], th, p[0] - x0, p[1] - y0];
    tops.push({ ...c, T, w: fwd(T, cu, cv), good: -Infinity, bad: 0, turned: true });
  }
  onStep("fitting the printed street corridors");
  const refined = [];
  const refine = async (c) => {
    const r = await corridorRefine(gpu, sheet, c, all);
    r.hits = hitsOf(r.T);
    r.whits = whits(r.T);
    r.contrast = await contrast(gpu, sheet, r.T);
    r.grid = gridOf(r.T);
    refined.push(r);
  };
  for (const c of tops) await refine(c);
  // the slide search: names that all lie on parallel streets pin a placement across those streets
  // but not along them, and a regular grid lines up a block off as well as anywhere. When nothing
  // can be accepted, slide the best placements along their streets (+-300 m) to where names on
  // crossing streets land too (Salem sheet 3: four names on parallel streets; 145 m along, four that cross).
  if (!refined.some(lines)) {
    const slid = [];
    for (const c of refined.slice().sort(byRank).slice(0, 3)) {
      const on = labelStatus(c.T, all).filter((l) => l.d <= LABEL_TOL);
      if (on.length < 2) continue;
      // the streets' direction, averaged as doubled angles (a street has no way round)
      let sx = 0, sy = 0;
      for (const l of on) {
        const n = nearestSeg(l.segs, l.x, l.y), a = 2 * Math.atan2(n.ey, n.ex);
        sx += Math.cos(a); sy += Math.sin(a);
      }
      if (Math.hypot(sx, sy) < 0.9 * on.length) continue; // they cross already
      const dir = Math.atan2(sy, sx) / 2, ex = Math.cos(dir), ey = Math.sin(dir), found = [];
      for (let d = -300; d <= 300; d += 5) {
        if (Math.abs(d) < 30) continue;
        const T = [c.T[0], c.T[1], c.T[2] + d * ex, c.T[3] + d * ey], cand = { T, hits: hitsOf(T) };
        if (passes(cand)) found.push({ ...cand, d });
      }
      found.sort((a, b) => b.hits - a.hits);
      const mine = [];
      for (const f of found) {
        if (mine.length >= 4) break;
        if (mine.some((m) => Math.abs(m.d - f.d) < 30)) continue;
        mine.push(f);
        slid.push({ ...c, T: f.T, w: fwd(f.T, cu, cv), hits: f.hits, good: -Infinity, bad: 0, slid: true });
      }
    }
    if (slid.length) onStep("sliding along the streets");
    for (const c of slid) await refine(c);
  }
  // (for attribution: the plain ranking's choice, before the pick's preference)
  const byRankWin = refined.slice().sort(byRank)[0];
  refined.sort(byPick);
  const win = refined[0];
  const rival = snapped.find((c) => Math.hypot(win.w[0] - c.w[0], win.w[1] - c.w[1]) > 60);
  return {
    T: win.T,
    hits: win.hits,
    rivalHits: rival ? rival.hits : 0,
    contrast: win.contrast,
    grid: win.grid,
    // how the winner was found: turned onto the grid; preferred over the plain ranking's choice
    turned: !!win.turned,
    slid: !!win.slid,
    preferred: win !== byRankWin,
    corridor: [win.good, win.bad],
    labels: all.length,
    nCand,
    pairs: pairs.length,
    msGpu: Math.round(msGpu),
    ms: Math.round(performance.now() - t0),

  };
}

// Dense search around a placement (+-40 m, +-3 deg, +-1 % scale), keeping every street name that
// was on its street; best = most modern street length inside printed street corridors (good - bad).
async function corridorRefine(gpu, sheet, c, labs, { move = 40, mstep = 2, deg = 3, dstep = 0.5, pct = 1 } = {}) {
  const [s0, th0] = c.T, [cu, cv] = sheet.centre, w = fwd(c.T, cu, cv);
  const Ts = [];
  for (let p = -pct; p <= pct + 1e-9; p += pct || 1)
    for (let d = -deg; d <= deg + 1e-9; d += dstep) {
      const s = s0 * (1 + p / 100), th = th0 + (d * Math.PI) / 180, [x0, y0] = fwd([s, th, 0, 0], cu, cv);
      for (let dx = -move; dx <= move + 1e-9; dx += mstep)
        for (let dy = -move; dy <= move + 1e-9; dy += mstep) Ts.push([s, th, w[0] - x0 + dx, w[1] - y0 + dy]);
    }
  const region = { x: w[0], y: w[1], r: sheet.radius * s0 * (1 + pct / 100) + 20 + move + 10 };
  const [sc, hits] = await Promise.all([gpu.corridor(Ts, region), gpu.labelHits(Ts)]);
  const need = (await gpu.labelHits([c.T]))[0];
  let k0 = -1;
  for (let k = 0; k < Ts.length; k++)
    if (hits[k] >= need && (k0 < 0 || sc[k][0] - sc[k][1] > sc[k0][0] - sc[k0][1])) k0 = k;
  if (k0 < 0 || sc[k0][0] - sc[k0][1] <= c.good - c.bad) return c;
  const T = Ts[k0];
  return { ...c, T, good: sc[k0][0], bad: sc[k0][1], w: fwd(T, cu, cv), refined: true };
}

// PERTURB: 8 directions, 20..120 m, every other one also turned 10 deg
const PERTURB = Array.from({ length: 8 }, (_, k) => [20 + (100 * k) / 7, (k * Math.PI) / 4, (-1) ** k * ((10 * Math.PI) / 180) * (k % 2)]);

// contrast counts streets only: "any ink within 3 m" passes rails on most busy sheets, which lifted wrong fits
export async function contrast(gpu, sheet, T) {
  const [cu, cv] = sheet.centre, w = fwd(T, cu, cv), Ts = [T];
  for (const [d, ang, dth] of PERTURB) {
    const th = T[1] + dth, [x0, y0] = fwd([T[0], th, 0, 0], cu, cv);
    Ts.push([T[0], th, w[0] - x0 + d * Math.cos(ang), w[1] - y0 + d * Math.sin(ang)]);
  }
  const sc = await gpu.corridor(Ts, { x: w[0], y: w[1], r: sheet.radius * T[0] + 20 + 130 }, 0);
  const frac = sc.map(([g, b]) => g / Math.max(g + b, 1));
  const rest = frac.slice(1).sort((a, b) => a - b);
  return frac[0] - (rest[3] + rest[4]) / 2;
}

/** contrast for many placements in one GPU dispatch (one region covering them all) */
async function contrastBatch(gpu, sheet, Ts) {
  if (!Ts.length) return [];
  const [cu, cv] = sheet.centre, all = [], ws = [];
  for (const T of Ts) {
    const w = fwd(T, cu, cv);
    ws.push(w);
    all.push(T);
    for (const [d, ang, dth] of PERTURB) {
      const th = T[1] + dth, [x0, y0] = fwd([T[0], th, 0, 0], cu, cv);
      all.push([T[0], th, w[0] - x0 + d * Math.cos(ang), w[1] - y0 + d * Math.sin(ang)]);
    }
  }
  const mx = ws.reduce((a, w) => a + w[0], 0) / ws.length, my = ws.reduce((a, w) => a + w[1], 0) / ws.length;
  const smax = Math.max(...Ts.map((T) => T[0]));
  const r = Math.max(...ws.map((w) => Math.hypot(w[0] - mx, w[1] - my))) + sheet.radius * smax + 20 + 130;
  const sc = await gpu.corridor(all, { x: mx, y: my, r }, 0);
  const out = [];
  for (let i = 0; i < Ts.length; i++) {
    const frac = sc.slice(9 * i, 9 * i + 9).map(([g, b]) => g / Math.max(g + b, 1));
    const rest = frac.slice(1).sort((a, b) => a - b);
    out.push(frac[0] - (rest[3] + rest[4]) / 2);
  }
  return out;
}
