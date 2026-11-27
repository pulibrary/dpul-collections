// In-browser OCR: a port of the server's priv/georef/ocr.py (RapidOCR with PP-OCRv6 small
// detection + recognition and the v2 angle classifier), run by onnxruntime-web on WebGPU.
// Each step follows RapidOCR (rapidocr/main.py, ch_ppocr_det|cls|rec): the same image sizes,
// BGR channel order, normalisation, DB box post-processing, crops, batching and CTC decoding.
import * as ort from "onnxruntime-web/webgpu";

const BASE = "/georeferencer/ocr/";
ort.env.wasm.wasmPaths = BASE;
ort.env.wasm.numThreads = 1; // no cross-origin isolation, so no wasm threads; the work is on the GPU

let loading = null;
export function loadOcr() {
  loading ||= (async () => {
    const opts = { executionProviders: ["webgpu", "wasm"], graphOptimizationLevel: "all" };
    const [det, cls, rec, keys] = await Promise.all([
      ort.InferenceSession.create(BASE + "det.onnx", opts),
      ort.InferenceSession.create(BASE + "cls.onnx", opts),
      ort.InferenceSession.create(BASE + "rec.onnx", opts),
      fetch(BASE + "keys.json").then((r) => r.json()),
    ]);
    return { det, cls, rec, chars: ["blank", ...keys, " "] };
  })();
  return loading;
}

// ---- images: {w, h, d: Uint8ClampedArray RGBA} ----------------------------------------

export function fromImage(img) {
  const w = img.naturalWidth || img.width, h = img.naturalHeight || img.height;
  const cv = new OffscreenCanvas(w, h), ctx = cv.getContext("2d", { willReadFrequently: true });
  ctx.drawImage(img, 0, 0);
  return { w, h, d: ctx.getImageData(0, 0, w, h).data };
}

// cv2.resize INTER_LINEAR (pixel centres aligned, no antialiasing)
function resize(src, W, H) {
  const out = new Uint8ClampedArray(W * H * 4), sx = src.w / W, sy = src.h / H, d = src.d;
  for (let y = 0; y < H; y++) {
    let fy = (y + 0.5) * sy - 0.5;
    if (fy < 0) fy = 0;
    const y0 = Math.min(Math.floor(fy), src.h - 1), y1 = Math.min(y0 + 1, src.h - 1), ay = fy - y0;
    for (let x = 0; x < W; x++) {
      let fx = (x + 0.5) * sx - 0.5;
      if (fx < 0) fx = 0;
      const x0 = Math.min(Math.floor(fx), src.w - 1), x1 = Math.min(x0 + 1, src.w - 1), ax = fx - x0;
      const a = (y0 * src.w + x0) * 4, b = (y0 * src.w + x1) * 4, c = (y1 * src.w + x0) * 4, e = (y1 * src.w + x1) * 4;
      const o = (y * W + x) * 4;
      for (let k = 0; k < 3; k++)
        out[o + k] = (d[a + k] * (1 - ax) + d[b + k] * ax) * (1 - ay) + (d[c + k] * (1 - ax) + d[e + k] * ax) * ay;
      out[o + 3] = 255;
    }
  }
  return { w: W, h: H, d: out };
}

// PIL rotate(-90, expand=True): clockwise; rotated (u, v) <- original (v, h - 1 - u)
export function rotateCW(src) {
  const W = src.h, H = src.w, out = new Uint8ClampedArray(W * H * 4);
  for (let v = 0; v < H; v++)
    for (let u = 0; u < W; u++) {
      const s = (( src.h - 1 - u) * src.w + v) * 4, o = (v * W + u) * 4;
      out[o] = src.d[s]; out[o + 1] = src.d[s + 1]; out[o + 2] = src.d[s + 2]; out[o + 3] = 255;
    }
  return { w: W, h: H, d: out };
}

// np.rot90 (counter-clockwise): new[i][j] = old[j][W - 1 - i]
function rot90(src) {
  const W = src.h, H = src.w, out = new Uint8ClampedArray(W * H * 4);
  for (let i = 0; i < H; i++)
    for (let j = 0; j < W; j++) {
      const s = (j * src.w + (src.w - 1 - i)) * 4, o = (i * W + j) * 4;
      out[o] = src.d[s]; out[o + 1] = src.d[s + 1]; out[o + 2] = src.d[s + 2]; out[o + 3] = 255;
    }
  return { w: W, h: H, d: out };
}

function rot180(src) {
  const out = new Uint8ClampedArray(src.d.length), n = src.w * src.h;
  for (let i = 0; i < n; i++) { const s = (n - 1 - i) * 4, o = i * 4; out[o] = src.d[s]; out[o + 1] = src.d[s + 1]; out[o + 2] = src.d[s + 2]; out[o + 3] = 255; }
  return { w: src.w, h: src.h, d: out };
}

// BGR, (x / 255 - 0.5) / 0.5, CHW, into `t` at batch slot `b` (width `TW`, zero padding right)
function putTensor(t, b, img, TW, TH) {
  const plane = TW * TH, base = b * 3 * plane;
  for (let y = 0; y < img.h; y++)
    for (let x = 0; x < img.w; x++) {
      const s = (y * img.w + x) * 4, o = y * TW + x;
      t[base + o] = img.d[s + 2] / 127.5 - 1;
      t[base + plane + o] = img.d[s + 1] / 127.5 - 1;
      t[base + 2 * plane + o] = img.d[s] / 127.5 - 1;
    }
}

// ---- detection (DB) ----------------------------------------------------------------------

const round32 = (v) => Math.round(v / 32) * 32;

function convexHull(pts) {
  pts.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lo = [], up = [];
  for (const p of pts) { while (lo.length >= 2 && cross(lo[lo.length - 2], lo[lo.length - 1], p) <= 0) lo.pop(); lo.push(p); }
  for (let i = pts.length - 1; i >= 0; i--) { const p = pts[i]; while (up.length >= 2 && cross(up[up.length - 2], up[up.length - 1], p) <= 0) up.pop(); up.push(p); }
  up.pop(); lo.pop();
  return lo.concat(up);
}

// cv2.minAreaRect by rotating calipers: {cx, cy, w, h, ang} with the 4 corners
function minAreaRect(hull) {
  if (hull.length === 1) return { pts: [hull[0], hull[0], hull[0], hull[0]], w: 0, h: 0 };
  let best = null;
  for (let i = 0; i < hull.length; i++) {
    const a = hull[i], b = hull[(i + 1) % hull.length];
    const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
    if (L < 1e-9) continue;
    const ux = (b[0] - a[0]) / L, uy = (b[1] - a[1]) / L;
    let mn0 = Infinity, mx0 = -Infinity, mn1 = Infinity, mx1 = -Infinity;
    for (const p of hull) {
      const s = p[0] * ux + p[1] * uy, t = -p[0] * uy + p[1] * ux;
      mn0 = Math.min(mn0, s); mx0 = Math.max(mx0, s); mn1 = Math.min(mn1, t); mx1 = Math.max(mx1, t);
    }
    const area = (mx0 - mn0) * (mx1 - mn1);
    if (!best || area < best.area) best = { area, ux, uy, mn0, mx0, mn1, mx1 };
  }
  const { ux, uy, mn0, mx0, mn1, mx1 } = best;
  const P = (s, t) => [s * ux - t * uy, s * uy + t * ux];
  return { pts: [P(mn0, mn1), P(mx0, mn1), P(mx0, mx1), P(mn0, mx1)], w: mx0 - mn0, h: mx1 - mn1, ux, uy, mn0, mx0, mn1, mx1 };
}

// DBPostProcess.get_mini_boxes ordering
function miniBox(pts) {
  const p = pts.slice().sort((a, b) => a[0] - b[0]);
  const [i1, i4] = p[1][1] > p[0][1] ? [0, 1] : [1, 0];
  const [i2, i3] = p[3][1] > p[2][1] ? [2, 3] : [3, 2];
  return [p[i1], p[i2], p[i3], p[i4]];
}

function inPoly(x, y, poly) {
  let ins = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[j];
    if (y1 > y !== y2 > y && x < ((x2 - x1) * (y - y1)) / (y2 - y1) + x1) ins = !ins;
  }
  return ins;
}

function boxScoreFast(pred, W, H, box) {
  const xs = box.map((p) => p[0]), ys = box.map((p) => p[1]);
  const x0 = Math.min(Math.max(Math.floor(Math.min(...xs)), 0), W - 1), x1 = Math.min(Math.max(Math.ceil(Math.max(...xs)), 0), W - 1);
  const y0 = Math.min(Math.max(Math.floor(Math.min(...ys)), 0), H - 1), y1 = Math.min(Math.max(Math.ceil(Math.max(...ys)), 0), H - 1);
  const poly = box.map(([x, y]) => [Math.trunc(x), Math.trunc(y)]);
  let s = 0, n = 0;
  for (let y = y0; y <= y1; y++)
    for (let x = x0; x <= x1; x++)
      if (inPoly(x + 0.5, y + 0.5, poly) || poly.some(([px, py]) => px === x && py === y)) { s += pred[y * W + x]; n++; }
  return n ? s / n : 0;
}

async function detect(m, img) {
  const H = round32(img.h), W = round32(img.w);
  const im = H === img.h && W === img.w ? img : resize(img, W, H);
  const t = new Float32Array(3 * W * H);
  putTensor(t, 0, im, W, H);
  const out = await m.det.run({ x: new ort.Tensor("float32", t, [1, 3, H, W]) });
  const pred = out[m.det.outputNames[0]].data;
  // threshold 0.3, then dilate with a 2x2 kernel (anchor (1, 1): max over x-1..x, y-1..y)
  const bit = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) bit[i] = pred[i] > 0.3 ? 1 : 0;
  const mask = new Uint8Array(W * H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++)
      mask[y * W + x] = bit[y * W + x] | (x > 0 && bit[y * W + x - 1]) | (y > 0 && bit[(y - 1) * W + x]) | (x > 0 && y > 0 && bit[(y - 1) * W + x - 1]);
  // 8-connected components
  const lab = new Int32Array(W * H), boxes = [];
  const stack = [];
  let comps = 0;
  for (let i = 0; i < W * H && comps < 1000; i++) {
    if (!mask[i] || lab[i]) continue;
    comps++;
    const pts = [];
    lab[i] = comps; stack.push(i);
    while (stack.length) {
      const k = stack.pop(), x = k % W, y = (k - x) / W;
      pts.push([x, y]);
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          const xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
          const kk = yy * W + xx;
          if (mask[kk] && !lab[kk]) { lab[kk] = comps; stack.push(kk); }
        }
    }
    const r = minAreaRect(convexHull(pts));
    if (Math.min(r.w, r.h) < 3) continue;
    const score = boxScoreFast(pred, W, H, miniBox(r.pts));
    if (score < 0.5) continue;
    // unclip (pyclipper round offset of the box by area * 1.6 / perimeter): its min-area rect
    // is the box grown by that distance on every side
    const dist = (r.w * r.h * 1.6) / (2 * (r.w + r.h));
    const g = { ...r, mn0: r.mn0 - dist, mx0: r.mx0 + dist, mn1: r.mn1 - dist, mx1: r.mx1 + dist };
    if (Math.min(r.w, r.h) + 2 * dist < 5) continue;
    const P = (s, tt) => [s * g.ux - tt * g.uy, s * g.uy + tt * g.ux];
    const box = miniBox([P(g.mn0, g.mn1), P(g.mx0, g.mn1), P(g.mx0, g.mx1), P(g.mn0, g.mx1)])
      .map(([x, y]) => [Math.min(Math.max(Math.round((x / W) * img.w), 0), img.w), Math.min(Math.max(Math.round((y / H) * img.h), 0), img.h)]);
    // filter_det_res: clockwise from top-left, clipped, at least 4 px each way
    const xs = box.slice().sort((a, b) => a[0] - b[0]);
    const [tl, bl] = xs.slice(0, 2).sort((a, b) => a[1] - b[1]), [tr, br] = xs.slice(2).sort((a, b) => a[1] - b[1]);
    const q = [tl, tr, br, bl].map(([x, y]) => [Math.trunc(Math.min(Math.max(x, 0), img.w - 1)), Math.trunc(Math.min(Math.max(y, 0), img.h - 1))]);
    if (Math.trunc(Math.hypot(q[0][0] - q[1][0], q[0][1] - q[1][1])) <= 3 || Math.trunc(Math.hypot(q[0][0] - q[3][0], q[0][1] - q[3][1])) <= 3) continue;
    boxes.push(q);
  }
  // sorted_boxes: top to bottom by lines (10 px), left to right within a line
  boxes.sort((a, b) => a[0][1] - b[0][1]);
  let line = 0;
  const keyed = boxes.map((b, i) => { if (i && b[0][1] - boxes[i - 1][0][1] >= 10) line++; return { b, line }; });
  keyed.sort((a, b) => a.line - b.line || a.b[0][0] - b.b[0][0]);
  return keyed.map((k) => k.b);
}

// get_rotate_crop_image: the box straightened to a w x h crop (bilinear, edge-replicated);
// tall crops turned 90 degrees counter-clockwise
function crop(img, q) {
  const w = Math.trunc(Math.max(Math.hypot(q[0][0] - q[1][0], q[0][1] - q[1][1]), Math.hypot(q[2][0] - q[3][0], q[2][1] - q[3][1])));
  const h = Math.trunc(Math.max(Math.hypot(q[0][0] - q[3][0], q[0][1] - q[3][1]), Math.hypot(q[1][0] - q[2][0], q[1][1] - q[2][1])));
  const out = new Uint8ClampedArray(Math.max(w, 1) * Math.max(h, 1) * 4);
  // bilinear map of the unit square onto the quad (the quads are near-rectangles)
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const u = (x + 0.5) / w, v = (y + 0.5) / h;
      const sx = (1 - v) * ((1 - u) * q[0][0] + u * q[1][0]) + v * ((1 - u) * q[3][0] + u * q[2][0]) - 0.5;
      const sy = (1 - v) * ((1 - u) * q[0][1] + u * q[1][1]) + v * ((1 - u) * q[3][1] + u * q[2][1]) - 0.5;
      const x0 = Math.min(Math.max(Math.floor(sx), 0), img.w - 1), y0 = Math.min(Math.max(Math.floor(sy), 0), img.h - 1);
      const x1 = Math.min(x0 + 1, img.w - 1), y1 = Math.min(y0 + 1, img.h - 1);
      const ax = Math.min(Math.max(sx - x0, 0), 1), ay = Math.min(Math.max(sy - y0, 0), 1);
      const o = (y * w + x) * 4;
      for (let k = 0; k < 3; k++) {
        const p = (yy, xx) => img.d[(yy * img.w + xx) * 4 + k];
        out[o + k] = (p(y0, x0) * (1 - ax) + p(y0, x1) * ax) * (1 - ay) + (p(y1, x0) * (1 - ax) + p(y1, x1) * ax) * ay;
      }
      out[o + 3] = 255;
    }
  const c = { w: Math.max(w, 1), h: Math.max(h, 1), d: out };
  return c.h / c.w >= 1.5 ? rot90(c) : c;
}

async function classify(m, crops) {
  if (!crops.length) return crops;
  const TW = 192, TH = 48, t = new Float32Array(crops.length * 3 * TW * TH);
  crops.forEach((c, b) => putTensor(t, b, resize(c, Math.min(TW, Math.ceil((TH * c.w) / c.h)), TH), TW, TH));
  const out = await m.cls.run({ x: new ort.Tensor("float32", t, [crops.length, 3, TH, TW]) });
  const p = out[m.cls.outputNames[0]].data;
  return crops.map((c, i) => (p[2 * i + 1] > p[2 * i] && p[2 * i + 1] > 0.9 ? rot180(c) : c));
}

async function recognise(m, crops) {
  const order = crops.map((c, i) => [c.w / c.h, i]).sort((a, b) => a[0] - b[0]).map((x) => x[1]);
  const res = new Array(crops.length);
  for (let b0 = 0; b0 < order.length; b0 += 6) {
    const idx = order.slice(b0, b0 + 6);
    const maxR = Math.max(320 / 48, ...idx.map((i) => crops[i].w / crops[i].h));
    const TW = Math.trunc(48 * maxR), TH = 48, t = new Float32Array(idx.length * 3 * TW * TH);
    idx.forEach((i, b) => {
      const c = crops[i], rw = Math.min(TW, Math.ceil((TH * c.w) / c.h));
      putTensor(t, b, resize(c, rw, TH), TW, TH);
    });
    const out = await m.rec.run({ x: new ort.Tensor("float32", t, [idx.length, 3, TH, TW]) });
    const o = out[m.rec.outputNames[0]], [, T, C] = o.dims, d = o.data;
    idx.forEach((i, b) => {
      let text = "", probs = [], prev = -1;
      for (let s = 0; s < T; s++) {
        let bi = 0, bp = -Infinity;
        const base = (b * T + s) * C;
        for (let k = 0; k < C; k++) if (d[base + k] > bp) { bp = d[base + k]; bi = k; }
        if (bi !== prev && bi !== 0) { text += m.chars[bi]; probs.push(Math.round(bp * 1e5) / 1e5); }
        prev = bi;
      }
      res[i] = { text, score: probs.length ? probs.reduce((a, x) => a + x, 0) / probs.length : 0 };
    });
  }
  return res;
}

/** RapidOCR's engine(img) with the server's settings: [{text, score, quad}] in img's pixels */
export async function runOcr(img) {
  const m = await loadOcr();
  // Global.max_side_len 2000: larger pages are read at 2000 px (sides rounded to 32)
  let im = img, rw = 1, rh = 1;
  if (Math.max(img.w, img.h) > 2000) {
    const r = 2000 / Math.max(img.w, img.h);
    const W = round32(Math.trunc(img.w * r)), H = round32(Math.trunc(img.h * r));
    im = resize(img, W, H); rw = img.w / W; rh = img.h / H;
  }
  const boxes = await detect(m, im);
  if (!boxes.length) return [];
  const crops = await classify(m, boxes.map((q) => crop(im, q)));
  const rec = await recognise(m, crops);
  const items = [];
  boxes.forEach((q, i) => {
    const { text, score } = rec[i];
    if (!text.trim() || score < 0.5) return;
    items.push({ text, score, quad: q.map(([x, y]) => [Math.min(Math.max(x * rw, 0), img.w), Math.min(Math.max(y * rh, 0), img.h)]) });
  });
  return items;
}

const bbox = (q) => [Math.min(...q.map((p) => p[0])), Math.min(...q.map((p) => p[1])), Math.max(...q.map((p) => p[0])), Math.max(...q.map((p) => p[1]))];
function overlaps(a, b) {
  const [ax0, ay0, ax1, ay1] = bbox(a), [bx0, by0, bx1, by1] = bbox(b);
  const ix = Math.max(0, Math.min(ax1, bx1) - Math.max(ax0, bx0)), iy = Math.max(0, Math.min(ay1, by1) - Math.max(ay0, by0));
  const small = Math.min((ax1 - ax0) * (ay1 - ay0), (bx1 - bx0) * (by1 - by0)) || 1;
  return (ix * iy) / small > 0.3;
}

/** ocr.py: the page upright, then turned 90 degrees for vertical names (kept where upright missed
 *  them or read them worse). -> [{text, score, quad}] in the page's pixels */
export async function readPage(img) {
  let items = await runOcr(img);
  const h = img.h;
  for (const it of await runOcr(rotateCW(img))) {
    const back = it.quad.map(([u, v]) => [v, h - 1 - u]);
    const [x0, y0, x1, y1] = bbox(back);
    if (y1 - y0 < 1.5 * (x1 - x0)) continue;
    const clash = items.filter((o) => overlaps(back, o.quad));
    if (clash.some((o) => o.score >= it.score)) continue;
    items = items.filter((o) => !clash.includes(o)).concat([{ text: it.text, score: it.score, quad: back }]);
  }
  return items;
}
