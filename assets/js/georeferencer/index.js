// LiveView hook for the collaborative georeferencer. Everything heavy runs here, on the
// contributor's machine: reading the sheet image, the GPU search, snapping, scoring. The server
// only supplies inputs (GET data-input) and stores the result (pushEvent "save").
import { fwd, inv, toAB, fromAB, prepareSheet, samplePoints, targetedLabels, labelStatus, snap,
         pointInPoly, nearestSeg, LABEL_TOL, nextFrame } from "./engine";
import { gpuDevice, makeGpu } from "./gpu";
import { findPlacement, scaleRange, distinctLabels } from "./search";
import * as ocr from "./ocr";
import { loadTown } from "./pipeline";


const BTN = "btn-secondary px-3 py-1 text-sm disabled:opacity-40";

export const Georeferencer = {
  async mounted() {
    this.el.innerHTML = `
      <div class="flex flex-wrap gap-2 items-center pb-2" data-role="tools">
        <button data-act="find" class="${BTN}">Find it again</button>
        <button data-act="snap" class="${BTN}" title="Pull the street names onto their streets from here">Snap to labels</button>
        <button data-act="rotl" class="${BTN}" title="Rotate the sheet 1° (or shift-drag)">⟲</button>
        <button data-act="rotr" class="${BTN}" title="Rotate the sheet 1°">⟳</button>
        <button data-act="reset" class="${BTN}">Back to my computer's fit</button>
        <label class="text-sm flex items-center gap-1">Sheet <input data-act="opacity" type="range" min="0" max="100" value="75"></label>
        <span class="grow"></span>
        <button data-act="save" class="btn-primary px-3 py-1 text-sm disabled:opacity-40">Save: it's right</button>
        <button data-act="cannot" class="${BTN}">Can't be placed</button>
      </div>
      <div data-role="names" class="flex flex-wrap gap-1 pb-2 text-xs"></div>
      <div class="relative">
        <canvas tabindex="0" class="block w-full h-[68vh] bg-white border border-sage-300 touch-none cursor-grab"></canvas>
        <div data-role="status" class="absolute top-2 left-2 bg-white/90 px-2 py-1 text-sm max-w-[80%]"></div>
      </div>
      <div data-role="stats" class="text-sm pt-2 font-mono"></div>
      <p class="text-xs pt-1"><b>Quickest:</b> click a street name above, its modern street lights up in orange; click on that
        street where the name belongs. Do it for a second name and the sheet is in place (scale and turn included).
        Or drag the sheet to move it, shift-drag to rotate, alt-scroll to resize; drag the background to pan, scroll to zoom;
        arrow keys nudge, &lt; &gt; turn, − + resize; hold Space to see the map through the sheet. Dots are the street names read from the sheet: green when on their modern street.</p>`;
    this.cv = this.el.querySelector("canvas");
    this.ctx = this.cv.getContext("2d");
    this.statusEl = this.el.querySelector("[data-role=status]");
    this.statsEl = this.el.querySelector("[data-role=stats]");
    this.namesEl = this.el.querySelector("[data-role=names]");
    this.pins = []; this.picked = null; this.tileErrors = 0;
    this.opacity = 0.75;
    this.bindUi();
    new ResizeObserver(() => this.redraw()).observe(this.cv);
    try {
      await this.load();
    } catch (e) {
      console.error(e);
      this.status(`Stopped: ${e.message}`);
    }
  },

  destroyed() { this.dead = true; window.removeEventListener("keydown", this.onKey); window.removeEventListener("keyup", this.onKeyUp); },

  status(msg) { this.statusEl.textContent = msg || ""; this.statusEl.hidden = !msg; },

  async load() {
    const t0 = performance.now();
    this.status("Fetching the sheet and the town's streets…");
    const input = await (await fetch(this.el.dataset.input)).json();
    const town = await loadTown(input.osm);
    this.town = town;
    input.lines = town.lines;
    input.targets = town.targets;
    this.input = input;
    const img = new Image();
    img.src = `${this.el.dataset.image}?service=${encodeURIComponent(input.canvas.service)}`;
    await img.decode();
    this.img = img;
    this.mask = input.canvas.mask;
    this.view = null;

    // a starting placement: centred on the town, at the atlas's usual scale, north up
    const range = scaleRange(input);
    this.range = range;
    this.T = this.startT();
    this.fitView();
    this.redraw();

    const tPrep = performance.now();
    this.sheet = await prepareSheet(ocr.fromImage(img), input.canvas.width, this.mask, (s) => this.status(`Reading the sheet on your computer: ${s}…`));
    this.pts = town.pts;
    this.labs = distinctLabels(targetedLabels(input.canvas.labels, input.targets));
    const msPrep = performance.now() - tPrep;
    if (this.dead) return;
    this.status("Starting your GPU…");
    this.gpuDev = await gpuDevice();
    this.gpu = await makeGpu(this.gpuDev, this.sheet, this.pts, this.labs);
    this.compute = { ms_prepare: Math.round(msPrep), gpu: this.gpuDev.info, ua: navigator.userAgent };
    if (this.gpuDev.info.fallback) this.compute.note = "software (CPU) WebGPU adapter";
    this.renderNames();
    if (input.auto) {
      // adjusting a part that was already fitted automatically, or checking the computer's
      // unconfirmed guess: start from that fit
      this.autoT = fromAB(input.auto); this.T = this.autoT.slice(); this.method = "auto";
      this.result = {}; this.fitView(); this.rescore();
      this.status({
        guess: "The computer's guess. If the dots are green and the streets line up, save it; otherwise pin two street names.",
        doubtful: "The computer's guess puts names on streets, but the printed streets don't line up with the modern ones: probably wrong. Pin two street names.",
      }[input.auto_status] || "");
    } else {
      await this.find();
    }
    this.compute.ms_total = Math.round(performance.now() - t0);
    this.done = true;
  },

  startT() {
    const c = this.input.canvas, s = (this.range.smin + this.range.smax) / 2;
    const u = this.mask.reduce((a, p) => a + p[0], 0) / this.mask.length;
    const v = this.mask.reduce((a, p) => a + p[1], 0) / this.mask.length;
    const T = [s, 0, 0, 0], [x, y] = fwd(T, u, v);
    return [s, 0, -x, -y];
  },

  async find() {
    this.status(`Searching for where ${this.labs.length} street names fit…`);
    await nextFrame();
    const r = await findPlacement(this.gpu, this.sheet, this.labs, this.range, (s) => this.status(`Searching: ${s}…`));
    this.result = r;
    Object.assign(this.compute, { ms_search: r.ms, ms_gpu: r.msGpu, candidates: r.nCand, pairs: r.pairs });
    if (r.error) {
      this.status(`Your computer couldn't place this part (${r.error}). Drag it into place by hand, or mark it "can't be placed".`);
      this.autoT = null;
    } else {
      this.status("");
      this.autoT = r.T.slice();
      this.T = r.T.slice();
      this.method = "auto";
      this.fitView();
    }
    this.redraw();
    this.rescore();
  },

  // ---- view -----------------------------------------------------------------------------
  fitView() {
    const [s] = this.T, xs = [], ys = [];
    for (const [u, v] of this.mask) { const [x, y] = fwd(this.T, u, v); xs.push(x); ys.push(y); }
    const w = Math.max(...xs) - Math.min(...xs), h = Math.max(...ys) - Math.min(...ys);
    const W = this.cv.clientWidth || 800, H = this.cv.clientHeight || 600;
    this.view = { x: (Math.max(...xs) + Math.min(...xs)) / 2, y: (Math.max(...ys) + Math.min(...ys)) / 2,
                  z: 0.85 * Math.min(W / w, H / h) };
  },
  toScreen(x, y) { const v = this.view; return [(x - v.x) * v.z + this.cv.clientWidth / 2, this.cv.clientHeight / 2 - (y - v.y) * v.z]; },
  toWorld(sx, sy) { const v = this.view; return [(sx - this.cv.clientWidth / 2) / v.z + v.x, v.y - (sy - this.cv.clientHeight / 2) / v.z]; },

  redraw() {
    if (this.raf) return;
    this.raf = requestAnimationFrame(() => { this.raf = null; this.draw(); });
  },

  draw() {
    if (!this.input || !this.view) return;
    const cv = this.cv, ctx = this.ctx, dpr = window.devicePixelRatio || 1;
    const W = cv.clientWidth, H = cv.clientHeight;
    if (cv.width !== W * dpr || cv.height !== H * dpr) { cv.width = W * dpr; cv.height = H * dpr; }
    const v = this.view, e = W / 2 - v.x * v.z, f = H / 2 + v.y * v.z;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = "#f7f6f3"; ctx.fillRect(0, 0, W, H);
    const world = () => ctx.setTransform(dpr * v.z, 0, 0, -dpr * v.z, dpr * e, dpr * f);
    const lines = (style, width, dash) => {
      world(); ctx.strokeStyle = style; ctx.lineWidth = width / v.z; ctx.setLineDash(dash.map((d) => d / v.z));
      ctx.beginPath();
      for (const L of this.input.lines) {
        if (dash.length ? L[0] !== 2 : L[0] !== 1) continue;
        ctx.moveTo(L[1], L[2]);
        for (let i = 3; i + 1 < L.length; i += 2) ctx.lineTo(L[i], L[i + 1]);
      }
      ctx.stroke(); ctx.setLineDash([]);
    };
    // the modern map underneath (OpenStreetMap tiles: names, buildings, water)
    if (!this.drawTiles()) { lines("#c9c4bb", 3, []); lines("#8a8070", 1.5, [6, 4]); }

    // neighbours' current placements, outlines only
    world(); ctx.lineWidth = 1.5 / v.z; ctx.strokeStyle = "rgba(90,110,90,.6)";
    for (const n of this.input.neighbours) this.outline(fromAB(n.transform), n.mask);

    // the sheet, clipped to the part
    const [s, th, tx, ty] = this.T, k = this.sheet ? this.sheet.f : this.img.naturalWidth / this.input.canvas.width;
    const c = Math.cos(th), n = Math.sin(th), z = v.z * s / k;
    ctx.save();
    ctx.setTransform(dpr * z * c, -dpr * z * n, dpr * z * n, dpr * z * c, dpr * (v.z * tx + e), dpr * (-v.z * ty + f));
    ctx.beginPath(); this.mask.forEach(([x, y], i) => (i ? ctx.lineTo(x * k, y * k) : ctx.moveTo(x * k, y * k)));
    ctx.closePath(); ctx.clip();
    ctx.globalAlpha = this.opacity; ctx.drawImage(this.img, 0, 0); ctx.globalAlpha = 1;
    ctx.restore();
    // modern streets over the sheet so the fit is visible
    lines("rgba(20,90,200,.55)", 1.2, []);
    this.streetNames();
    world(); ctx.strokeStyle = "#a0562c"; ctx.lineWidth = 2 / v.z; this.outline(this.T, this.mask);

    // the picked name's modern street, and pinned names
    if (this.picked) {
      world(); ctx.strokeStyle = "rgba(234,88,12,.85)"; ctx.lineWidth = 7 / v.z; ctx.lineCap = "round"; ctx.beginPath();
      const g = this.picked.segs;
      for (let i = 0; i + 3 < g.length; i += 4) { ctx.moveTo(g[i], g[i + 1]); ctx.lineTo(g[i + 2], g[i + 3]); }
      ctx.stroke(); ctx.lineCap = "butt";
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    for (const p of this.pins) {
      const [sx, sy] = this.toScreen(p.x, p.y);
      ctx.strokeStyle = "#7c2d12"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(sx, sy, 8, 0, 7); ctx.stroke();
    }

    // labels
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.font = "11px sans-serif";
    for (const l of this.labelState || []) {
      const [sx, sy] = this.toScreen(l.x, l.y), on = l.d <= LABEL_TOL;
      ctx.fillStyle = on ? "#15803d" : "#d97706";
      ctx.beginPath(); ctx.arc(sx, sy, this.picked && this.picked.key === l.key ? 7 : 4.5, 0, 7); ctx.fill();
      if (v.z > 0.4) { ctx.fillStyle = "#222"; ctx.fillText(l.name, sx + 6, sy - 5); }
    }
  },

  // OSM raster tiles drawn into the atlas's local projection (x = (lon - lon0) kx, y = (lat - lat0) ky);
  // over a town, a mercator tile mapped by its corner lon/lat is accurate to well under a pixel
  drawTiles() {
    const pr = this.input.projection;
    if (!pr || this.noTiles) return false;
    const W = this.cv.clientWidth, H = this.cv.clientHeight, dpr = window.devicePixelRatio || 1;
    const ll = (sx, sy) => { const [x, y] = this.toWorld(sx, sy); return [pr.lon0 + x / pr.kx, pr.lat0 + y / pr.ky]; };
    const [lonA, latN] = ll(0, 0), [lonB, latS] = ll(W, H);
    const mpp = 1 / this.view.z; // metres per screen px
    const z = Math.max(3, Math.min(19, Math.round(Math.log2((156543.03 * Math.cos(pr.lat0 * Math.PI / 180)) / (mpp / dpr)))));
    const n = 2 ** z, tx = (lon) => ((lon + 180) / 360) * n;
    const ty = (lat) => { const r = (lat * Math.PI) / 180; return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n; };
    const lonOf = (x) => (x / n) * 360 - 180, latOf = (y) => (Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / n))) * 180) / Math.PI;
    const x0 = Math.floor(tx(lonA)), x1 = Math.floor(tx(lonB)), y0 = Math.floor(ty(latN)), y1 = Math.floor(ty(latS));
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > 120) return false;
    this.tiles ||= new Map();
    const ctx = this.ctx;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    for (let x = x0; x <= x1; x++) for (let y = y0; y <= y1; y++) {
      const key = `${z}/${x}/${y}`;
      let img = this.tiles.get(key);
      if (!img) {
        img = new Image();
        img.onload = () => this.redraw();
        img.onerror = () => { if (++this.tileErrors > 20) this.noTiles = true; };
        img.src = `https://tile.openstreetmap.org/${key}.png`;
        this.tiles.set(key, img);
        if (this.tiles.size > 600) this.tiles.delete(this.tiles.keys().next().value);
      }
      if (!img.complete || !img.naturalWidth) continue;
      const toS = (lon, lat) => this.toScreen((lon - pr.lon0) * pr.kx, (lat - pr.lat0) * pr.ky);
      const [ax, ay] = toS(lonOf(x), latOf(y)), [bx, by] = toS(lonOf(x + 1), latOf(y + 1));
      ctx.drawImage(img, ax, ay, bx - ax + 0.5, by - ay + 0.5);
    }
    ctx.fillStyle = "rgba(255,255,255,.25)"; ctx.fillRect(0, 0, W, H); // calm the map a little
    ctx.fillStyle = "#444"; ctx.font = "10px sans-serif"; ctx.fillText("© OpenStreetMap contributors", W - 150, H - 6);
    return true;
  },

  // modern street names along the blue lines (where the sheet hides the map's own labels)
  streetNames() {
    const t = this.town, v = this.view;
    if (!t || v.z < 0.35) return;
    const ctx = this.ctx, dpr = window.devicePixelRatio || 1, W = this.cv.clientWidth, H = this.cv.clientHeight, placed = [];
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.font = "600 11px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    for (const [key, g] of Object.entries(t.targets)) {
      // its longest on-screen segment
      let best = null;
      for (let i = 0; i + 3 < g.length; i += 4) {
        const [ax, ay] = this.toScreen(g[i], g[i + 1]), [bx, by] = this.toScreen(g[i + 2], g[i + 3]);
        const mx = (ax + bx) / 2, my = (ay + by) / 2, len = Math.hypot(bx - ax, by - ay);
        if (mx < 0 || my < 0 || mx > W || my > H) continue;
        if (!best || len > best.len) best = { mx, my, len, ang: Math.atan2(by - ay, bx - ax) };
      }
      const name = key.replace(/\b\p{L}/gu, (c) => c.toUpperCase());
      if (!best || best.len < ctx.measureText(name).width * 0.8) continue;
      if (placed.some(([x, y]) => Math.hypot(x - best.mx, y - best.my) < 70)) continue;
      placed.push([best.mx, best.my]);
      let a = best.ang; if (a > Math.PI / 2) a -= Math.PI; if (a < -Math.PI / 2) a += Math.PI;
      ctx.save(); ctx.translate(best.mx, best.my); ctx.rotate(a);
      const picked = this.picked && this.picked.key === key;
      ctx.lineWidth = 3; ctx.strokeStyle = "rgba(255,255,255,.9)"; ctx.strokeText(name, 0, 0);
      ctx.fillStyle = picked ? "#c2410c" : "#1e3a8a"; ctx.fillText(name, 0, 0);
      ctx.restore();
    }
    ctx.textAlign = "start"; ctx.textBaseline = "alphabetic";
  },

  outline(T, mask) {
    const ctx = this.ctx;
    ctx.beginPath();
    mask.forEach(([u, w], i) => { const [x, y] = fwd(T, u, w); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
    ctx.closePath(); ctx.stroke();
  },

  // ---- scores ---------------------------------------------------------------------------
  rescore() {
    if (!this.labs) return;
    this.labelState = labelStatus(this.T, this.labs);
    const hits = this.labelState.filter((l) => l.d <= LABEL_TOL).length;
    this.scores = { label_hits: hits, labels: this.labs.length, labels_read: this.input.canvas.labels.length };
    this.renderNames();
    this.renderStats();
    clearTimeout(this.corrTimer);
    this.corrTimer = setTimeout(async () => {
      if (!this.gpu) return;
      const T = this.T.slice(), [cu, cv] = this.sheet.centre, [x, y] = fwd(T, cu, cv);
      const [[g, b]] = await this.gpu.corridor([T], { x, y, r: this.sheet.radius * T[0] + 20 });
      Object.assign(this.scores, { corridor_good_m: g, corridor_bad_m: b });
      this.renderStats();
    }, 120);
    this.redraw();
  },

  renderStats() {
    const s = this.scores || {}, r = this.result || {}, c = this.compute || {};
    const pct = s.corridor_good_m != null ? Math.round((100 * s.corridor_good_m) / Math.max(1, s.corridor_good_m + s.corridor_bad_m)) : "…";
    const verdict = this.autoT && this.method === "auto"
      ? (r.hits >= 4 && r.contrast >= 0.09 ? "confident" : "unsure: check it carefully") : "placed by hand";
    this.statsEl.innerHTML =
      `<b>${s.label_hits}/${s.labels}</b> street names on their street · streets in printed corridors <b>${pct}%</b>` +
      ` · ${verdict}${r.contrast != null && this.method === "auto" ? ` (corridor contrast ${r.contrast.toFixed(2)}, next-best place: ${r.rivalHits} names)` : ""}<br>` +
      `your computer: read sheet ${c.ms_prepare ?? "…"} ms, searched ${r.nCand ? (r.nCand / 1e6).toFixed(1) + "M" : "…"} placements` +
      ` in ${r.msGpu ?? "…"} ms on ${c.gpu ? [c.gpu.vendor, c.gpu.architecture].filter(Boolean).join(" ") || "GPU" : "…"}` +
      `${c.note ? ` (${c.note})` : ""}`;
  },

  // ---- interaction ------------------------------------------------------------------------
  moved() { this.method = "adjusted"; this.rescore(); },

  rotateBy(rad) {
    const [cu, cv] = this.sheet ? this.sheet.centre : [0, 0], [x0, y0] = fwd(this.T, cu, cv);
    this.T[1] += rad;
    const [x1, y1] = fwd(this.T, cu, cv);
    this.T[2] += x0 - x1; this.T[3] += y0 - y1;
    this.moved();
  },

  scaleBy(k) {
    const [cu, cv] = this.sheet ? this.sheet.centre : [0, 0], [x0, y0] = fwd(this.T, cu, cv);
    this.T[0] *= k;
    const [x1, y1] = fwd(this.T, cu, cv);
    this.T[2] += x0 - x1; this.T[3] += y0 - y1;
    this.moved();
  },

  // ---- pinning street names ---------------------------------------------------------------
  renderNames() {
    if (!this.labs) return;
    const on = new Set((this.labelState || []).filter((l) => l.d <= LABEL_TOL).map((l) => l.key));
    const pinned = new Set(this.pins.map((p) => p.lab.key));
    this.namesEl.innerHTML = this.labs.length
      ? `<span class="self-center pr-1">Street names on this sheet:</span>` + this.labs.map((l, i) =>
        `<button data-lab="${i}" class="px-2 py-0.5 border ${this.picked === l ? "bg-orange-600 text-white border-orange-700" :
          on.has(l.key) ? "bg-emerald-50 border-emerald-600 text-emerald-900" : "bg-white border-stone-400"}">` +
        `${pinned.has(l.key) ? "📍 " : ""}${l.name.replace(/[<&]/g, "")}</button>`).join("")
      : `<span>No street names matched the town's streets: drag the sheet into place, or mark it "can't be placed".</span>`;
    this.namesEl.querySelectorAll("[data-lab]").forEach((b) => (b.onclick = () => this.pick(this.labs[+b.dataset.lab])));
  },

  pick(lab) {
    this.picked = this.picked === lab ? null : lab;
    this.renderNames(); this.redraw();
    if (!this.picked) return this.status("");
    // show the whole street, and the sheet
    const xs = [], ys = [], g = lab.segs;
    for (let i = 0; i + 1 < g.length; i += 2) { xs.push(g[i]); ys.push(g[i + 1]); }
    const W = this.cv.clientWidth, H = this.cv.clientHeight, [lx, ly] = fwd(this.T, lab.u, lab.v);
    xs.push(lx); ys.push(ly);
    const w = Math.max(...xs) - Math.min(...xs) + 100, h = Math.max(...ys) - Math.min(...ys) + 100;
    this.view = { x: (Math.max(...xs) + Math.min(...xs)) / 2, y: (Math.max(...ys) + Math.min(...ys)) / 2, z: 0.85 * Math.min(W / w, H / h) };
    this.redraw();
    this.status(`Click on the orange street where "${lab.name}" belongs.`);
  },

  // the picked name belongs at (x, y): one pin moves the sheet there, two fix it in place
  pin(x, y) {
    const lab = this.picked, n = nearestSeg(lab.segs, x, y);
    this.pins = this.pins.filter((p) => p.lab.key !== lab.key).concat([{ lab, x: n.fx, y: n.fy }]).slice(-2);
    if (this.pins.length === 1) {
      const [x0, y0] = fwd(this.T, lab.u, lab.v);
      this.T[2] += n.fx - x0; this.T[3] += n.fy - y0;
    } else {
      // z = A w + t with z = x + iy, w = u - iv (the sheet's v runs down), A = s e^{i th}
      const [p, q] = this.pins, du = p.lab.u - q.lab.u, dv = -(p.lab.v - q.lab.v), dx = p.x - q.x, dy = p.y - q.y;
      const d2 = du * du + dv * dv;
      const ar = (dx * du + dy * dv) / d2, ai = (dy * du - dx * dv) / d2;
      const s = Math.hypot(ar, ai), th = Math.atan2(ai, ar);
      const wu = p.lab.u, wv = -p.lab.v;
      this.T = [s, th, p.x - (ar * wu - ai * wv), p.y - (ar * wv + ai * wu)];
      // then let every name pull onto its street, if that keeps at least as many on
      const before = labelStatus(this.T, this.labs).filter((l) => l.d <= LABEL_TOL).length;
      const snapped = snap(this.T, this.labs, { radius: 25, s0: s });
      if (snapped && labelStatus(snapped, this.labs).filter((l) => l.d <= LABEL_TOL).length >= before) this.T = snapped;
    }
    this.picked = null;
    this.moved();
    if (this.pins.length === 1) this.status("Moved. Now pick a second street name, far from the first if you can.");
    else { this.fitView(); this.status("In place? Save it. Not quite? Pin another name or drag."); }
  },

  bindKeys() {
    this.onKey = (ev) => {
      if (!this.T || /input|textarea|select/i.test(ev.target.tagName) || !this.el.isConnected) return;
      const step = (ev.shiftKey ? 50 : 10) / this.view.z, k = ev.key;
      const moves = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, step], ArrowDown: [0, -step] };
      if (moves[k]) { this.T[2] += moves[k][0]; this.T[3] += moves[k][1]; this.moved(); }
      else if (k === "<" || k === ",") this.rotateBy(Math.PI / 360);
      else if (k === ">" || k === ".") this.rotateBy(-Math.PI / 360);
      else if (k === "-" || k === "_") this.scaleBy(1 / 1.01);
      else if (k === "+" || k === "=") this.scaleBy(1.01);
      else if (k === "Escape" && this.picked) this.pick(this.picked);
      else if (k === " ") { if (!this.peek) { this.peek = this.opacity; this.opacity = 0.15; this.redraw(); } }
      else return;
      ev.preventDefault();
    };
    window.addEventListener("keydown", this.onKey);
    this.onKeyUp = (ev) => { if (ev.key === " " && this.peek) { this.opacity = this.peek; this.peek = null; this.redraw(); } };
    window.addEventListener("keyup", this.onKeyUp);
  },

  bindUi() {
    this.bindKeys();
    const q = (a) => this.el.querySelector(`[data-act=${a}]`);
    q("find").onclick = () => this.gpu && this.find();
    q("snap").onclick = () => {
      if (!this.labs) return;
      const T = snap(this.T, this.labs, { radius: 25, s0: this.T[0] });
      if (T) { this.T = T; this.moved(); } else this.status("Not enough street names near their streets to snap from here.");
    };
    q("rotl").onclick = () => this.rotateBy((Math.PI / 180));
    q("rotr").onclick = () => this.rotateBy(-(Math.PI / 180));
    q("reset").onclick = () => { if (this.autoT) { this.T = this.autoT.slice(); this.method = "auto"; this.pins = []; this.rescore(); } };
    q("opacity").oninput = (e) => { this.opacity = e.target.value / 100; this.redraw(); };
    q("save").onclick = () => this.save("placed");
    q("cannot").onclick = () => this.save("cannot");

    let drag = null;
    this.cv.addEventListener("pointerdown", (ev) => {
      const r = this.cv.getBoundingClientRect(), sx = ev.clientX - r.left, sy = ev.clientY - r.top;
      const [x, y] = this.toWorld(sx, sy), [u, v] = inv(this.T, x, y);
      const onSheet = pointInPoly(u, v, this.mask);
      const [cu, cv] = this.sheet ? this.sheet.centre : [u, v], [cx, cy] = this.toScreen(...fwd(this.T, cu, cv));
      drag = { sx, sy, x0: sx, y0: sy, mode: onSheet && !this.picked ? (ev.shiftKey ? "rotate" : "move") : "pan", ang: Math.atan2(sy - cy, sx - cx), cx, cy };
      this.cv.setPointerCapture(ev.pointerId);
    });
    this.cv.addEventListener("pointermove", (ev) => {
      if (!drag) return;
      const r = this.cv.getBoundingClientRect(), sx = ev.clientX - r.left, sy = ev.clientY - r.top;
      const dx = (sx - drag.sx) / this.view.z, dy = -(sy - drag.sy) / this.view.z;
      if (drag.mode === "pan") { this.view.x -= dx; this.view.y -= dy; this.redraw(); }
      else if (drag.mode === "move") { this.T[2] += dx; this.T[3] += dy; this.moved(); }
      else {
        const a = Math.atan2(sy - drag.cy, sx - drag.cx);
        this.rotateBy(-(a - drag.ang)); drag.ang = a;
      }
      drag.sx = sx; drag.sy = sy;
    });
    const end = () => { drag = null; };
    this.cv.addEventListener("pointerup", (ev) => {
      // a click (not a drag) with a name picked: pin it there
      if (drag && this.picked && Math.hypot(drag.sx - drag.x0, drag.sy - drag.y0) < 4) {
        const r = this.cv.getBoundingClientRect();
        this.pin(...this.toWorld(ev.clientX - r.left, ev.clientY - r.top));
      }
      end();
    });
    this.cv.addEventListener("pointercancel", end);
    this.cv.addEventListener("wheel", (ev) => {
      ev.preventDefault();
      if (ev.altKey) return this.scaleBy(Math.exp(-ev.deltaY * 0.0005));
      const r = this.cv.getBoundingClientRect(), sx = ev.clientX - r.left, sy = ev.clientY - r.top;
      const [x, y] = this.toWorld(sx, sy);
      this.view.z *= Math.exp(-ev.deltaY * 0.0015);
      const [x2, y2] = this.toWorld(sx, sy);
      this.view.x += x - x2; this.view.y += y - y2;
      this.redraw();
    }, { passive: false });
  },

  save(verdict) {
    const payload = { verdict, compute: this.compute || {} };
    if (verdict === "placed") Object.assign(payload, { method: this.method || "adjusted", transform: toAB(this.T), scores: this.scores || {} });
    if (this.result && !this.result.error)
      payload.scores = { ...(payload.scores || {}), rival_hits: this.result.rivalHits, auto_contrast: this.result.contrast };
    this.pushEvent("save", payload, (reply) => {
      this.status(reply.ok ? "Saved. Thank you!" : reply.error);
      if (reply.ok) setTimeout(() => this.status(""), 2500);
    });
  },
};
