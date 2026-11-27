// CPU side of the in-browser georeferencer: the sheet's ink / distance / mask maps (a port of
// priv/georef/corridor.py Sheet), OSM sampling for the corridor score, label geometry and the
// label least-squares snap. Transform convention as the server: T = [s, th, tx, ty],
// world (m) = s * R(th) * [u, -v] + t  for canvas pixel (u, v); {a, b} = s * {cos th, sin th}.

export const fwd = ([s, th, tx, ty], u, v) => {
  const c = Math.cos(th), n = Math.sin(th);
  return [s * (c * u + n * v) + tx, s * (n * u - c * v) + ty];
};
export const inv = ([s, th, tx, ty], x, y) => {
  const c = Math.cos(th), n = Math.sin(th), dx = (x - tx) / s, dy = (y - ty) / s;
  return [c * dx + n * dy, n * dx - c * dy];
};
export const toAB = ([s, th, tx, ty]) => ({ a: s * Math.cos(th), b: s * Math.sin(th), tx, ty });
export const fromAB = ({ a, b, tx, ty }) => [Math.hypot(a, b), Math.atan2(b, a), tx, ty];

export const nextFrame = () => new Promise((r) => requestAnimationFrame(() => setTimeout(r, 0)));
export const nextTick = () => new Promise((r) => setTimeout(r, 0)); // also in workers

// ---- sheet maps -------------------------------------------------------------------------

const reflect = (i, n) => (i < 0 ? -i : i >= n ? 2 * n - 2 - i : i); // BORDER_REFLECT_101

// box mean (cv2.blur, ksize k, reflect-101 border), separable sliding sums
function boxBlur(src, W, H, k) {
  const r = k >> 1, tmp = new Float32Array(W * H), out = new Float32Array(W * H);
  for (let y = 0; y < H; y++) {
    const o = y * W;
    let s = 0;
    for (let i = -r; i <= r; i++) s += src[o + reflect(i, W)];
    for (let x = 0; x < W; x++) {
      tmp[o + x] = s;
      s += src[o + reflect(x + r + 1, W)] - src[o + reflect(x - r, W)];
    }
  }
  for (let x = 0; x < W; x++) {
    let s = 0;
    for (let i = -r; i <= r; i++) s += tmp[reflect(i, H) * W + x];
    for (let y = 0; y < H; y++) {
      out[y * W + x] = s / (k * k);
      s += tmp[reflect(y + r + 1, H) * W + x] - tmp[reflect(y - r, H) * W + x];
    }
  }
  return out;
}

// separable binary dilate (max) / erode (min) with a k x k square; outside = no-op
function morph(src, W, H, k, isMax) {
  const r = k >> 1, tmp = new Uint8Array(W * H), out = new Uint8Array(W * H);
  const pick = isMax ? (a, b) => a | b : (a, b) => a & b;
  for (let y = 0; y < H; y++) {
    const o = y * W;
    for (let x = 0; x < W; x++) {
      let v = isMax ? 0 : 1;
      for (let i = Math.max(0, x - r); i <= Math.min(W - 1, x + r); i++) v = pick(v, src[o + i]);
      tmp[o + x] = v;
    }
  }
  for (let x = 0; x < W; x++)
    for (let y = 0; y < H; y++) {
      let v = isMax ? 0 : 1;
      for (let i = Math.max(0, y - r); i <= Math.min(H - 1, y + r); i++) v = pick(v, tmp[i * W + x]);
      out[y * W + x] = v;
    }
  return out;
}

// exact Euclidean distance (px) to the nearest ink pixel (Felzenszwalb & Huttenlocher)
function edt(ink, W, H) {
  const INF = 1e20, g = new Float32Array(W * H);
  const n = Math.max(W, H), f = new Float64Array(n), d = new Float64Array(n), z = new Float64Array(n + 1);
  const v = new Int32Array(n);
  const pass = (len) => {
    let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
    const cross = (q, p) => (f[q] + q * q - (f[p] + p * p)) / (2 * q - 2 * p);
    for (let q = 1; q < len; q++) {
      let s = cross(q, v[k]);
      while (s <= z[k]) { k--; s = cross(q, v[k]); }
      k++; v[k] = q; z[k] = s; z[k + 1] = INF;
    }
    k = 0;
    for (let q = 0; q < len; q++) {
      while (z[k + 1] < q) k++;
      d[q] = (q - v[k]) ** 2 + f[v[k]];
    }
  };
  for (let x = 0; x < W; x++) {
    for (let y = 0; y < H; y++) f[y] = ink[y * W + x] ? 0 : INF;
    pass(H);
    for (let y = 0; y < H; y++) g[y * W + x] = d[y];
  }
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) f[x] = g[y * W + x];
    pass(W);
    for (let x = 0; x < W; x++) g[y * W + x] = Math.sqrt(d[x]);
  }
  return g;
}

/** the sheet's ink maps, once per canvas. img: {w, h, d: RGBA} of the "3000," image;
 *  width: the canvas width it was cut from -> {W, H, f, ink (dilated), dt} */
export async function prepareInk(img, width, onStep = () => {}) {
  const W = img.w, H = img.h, f = W / width, px = img.d;
  onStep("ink"); await nextTick();
  const V = new Float32Array(W * H), S = new Uint8Array(W * H);
  for (let i = 0, j = 0; i < W * H; i++, j += 4) {
    const r = px[j], g = px[j + 1], b = px[j + 2], mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    V[i] = mx; S[i] = mx === 0 ? 0 : Math.round((255 * (mx - mn)) / mx);
  }
  const bl = boxBlur(V, W, H, 31), ink = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) ink[i] = V[i] < Math.round(bl[i]) - 25 || V[i] < 110 || S[i] > 70 ? 1 : 0;
  onStep("corridors"); await nextTick();
  return { W, H, f, ink: morph(ink, W, H, 5, true), dt: edt(ink, W, H) };
}

/** a part of the sheet: the ink maps plus the part's eroded mask, centre and radius */
export function partSheet(inkMaps, maskPoly) {
  const { W, H, f } = inkMaps;
  const cv = new OffscreenCanvas(W, H), ctx = cv.getContext("2d", { willReadFrequently: true });
  ctx.fillStyle = "#fff"; ctx.beginPath();
  maskPoly.forEach(([x, y], k) => (k ? ctx.lineTo(x * f, y * f) : ctx.moveTo(x * f, y * f)));
  ctx.closePath(); ctx.fill();
  const a = ctx.getImageData(0, 0, W, H).data, m0 = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) m0[i] = a[4 * i + 3] > 127 ? 1 : 0;
  const mask = morph(m0, W, H, 15, false);
  const cx = maskPoly.reduce((s, p) => s + p[0], 0) / maskPoly.length;
  const cy = maskPoly.reduce((s, p) => s + p[1], 0) / maskPoly.length;
  const radius = Math.max(...maskPoly.map(([x, y]) => Math.hypot(x - cx, y - cy)));
  return { ...inkMaps, mask, centre: [cx, cy], radius };
}

/** both at once (the interactive editor) */
export async function prepareSheet(img, width, maskPoly, onStep = () => {}) {
  return partSheet(await prepareInk(img, width, onStep), maskPoly);
}

// ---- OSM ----------------------------------------------------------------------------------

/** drawn streets every 3 m with unit normals; railways every 3 m with nx = 9 (corridor.py Osm) */
export function samplePoints(lines) {
  const out = [];
  for (const L of lines) {
    const kind = L[0];
    for (let i = 1; i + 3 < L.length; i += 2) {
      const ax = L[i], ay = L[i + 1], bx = L[i + 2], by = L[i + 3], dx = bx - ax, dy = by - ay;
      const len = Math.hypot(dx, dy);
      if (kind === 1 && len < 1e-6) continue;
      const n = Math.floor(len / 3) + 1;
      const nx = kind === 1 ? -dy / len : 9, ny = kind === 1 ? dx / len : 9;
      for (let k = 0; k < n; k++) out.push(ax + (dx * k) / n, ay + (dy * k) / n, nx, ny);
    }
  }
  return new Float32Array(out);
}

/** labels whose key has a modern feature: [{u, v, key, segs: Float32Array(ax, ay, bx, by...)}] */
export function targetedLabels(labels, targets) {
  return labels
    .filter((l) => targets[l.key] && targets[l.key].length >= 4)
    .map((l) => ({ name: l.name, key: l.key, u: l.px[0], v: l.px[1], h: l.height || 0, segs: targets[l.key] }));
}

export function nearestSeg(segs, x, y) { return nearestOn(segs, x, y); }

function nearestOn(segs, x, y) {
  let best = 1e18, fx = 0, fy = 0, ex = 1, ey = 0;
  for (let i = 0; i + 3 < segs.length; i += 4) {
    const ax = segs[i], ay = segs[i + 1], dx = segs[i + 2] - ax, dy = segs[i + 3] - ay;
    const L2 = Math.max(dx * dx + dy * dy, 1e-9);
    const u = Math.min(1, Math.max(0, ((x - ax) * dx + (y - ay) * dy) / L2));
    const px = ax + u * dx, py = ay + u * dy, d = (x - px) ** 2 + (y - py) ** 2;
    if (d < best) { best = d; fx = px; fy = py; const l = Math.sqrt(L2); ex = dx / l; ey = dy / l; }
  }
  return { d: Math.sqrt(best), fx, fy, ex, ey };
}

export const LABEL_TOL = 8; // m: a label "on its street" (the server's label check)

export function labelStatus(T, labs) {
  return labs.map((l) => {
    const [x, y] = fwd(T, l.u, l.v);
    return { ...l, x, y, d: nearestOn(l.segs, x, y).d };
  });
}

/** labels-only least squares (priv/georef/corridor.py snap): each label within `radius` m of its
 *  street is pulled onto its nearest segment; weak prior keeps the scale near s0. */
export function snap(T, labs, { radius = 25, iters = 8, s0 = T[0], priorWeight = 40 } = {}) {
  let [s, th, tx, ty] = T;
  for (let it = 0; it < iters; it++) {
    const rows = [];
    for (const l of labs) {
      const [x, y] = fwd([s, th, tx, ty], l.u, l.v);
      const n = nearestOn(l.segs, x, y);
      if (n.d > radius) continue;
      const nx = -n.ey, ny = n.ex, wx = x - tx, wy = y - ty;
      rows.push([nx * wx + ny * wy, nx * -wy + ny * wx, nx, ny, -(nx * (x - n.fx) + ny * (y - n.fy))]);
    }
    if (rows.length < 2) return null;
    // prior: log scale toward s0 (priorWeight m of residual per unit of log scale)
    rows.push([priorWeight, 0, 0, 0, -priorWeight * Math.log(s / s0)]);
    if (rows.length < 5) rows.push([0, 0, 0, 0, 0]);
    const A = Array.from({ length: 4 }, () => new Float64Array(5));
    for (const r of rows) for (let i = 0; i < 4; i++) { for (let j = 0; j < 4; j++) A[i][j] += r[i] * r[j]; A[i][4] += r[i] * r[4]; }
    for (let i = 0; i < 4; i++) A[i][i] += 1e-6;
    const dx = solve4(A);
    if (!dx) return null;
    s *= Math.exp(dx[0]); th += dx[1]; tx += dx[2]; ty += dx[3];
    if (Math.abs(dx[2]) < 0.02 && Math.abs(dx[3]) < 0.02) break;
  }
  return [s, th, tx, ty];
}

function solve4(A) {
  for (let c = 0; c < 4; c++) {
    let p = c;
    for (let r = c + 1; r < 4; r++) if (Math.abs(A[r][c]) > Math.abs(A[p][c])) p = r;
    if (Math.abs(A[p][c]) < 1e-12) return null;
    [A[c], A[p]] = [A[p], A[c]];
    for (let r = 0; r < 4; r++) if (r !== c) {
      const k = A[r][c] / A[c][c];
      for (let j = c; j < 5; j++) A[r][j] -= k * A[c][j];
    }
  }
  return A.map((row, i) => row[4] / row[i]);
}

/** points every `step` m along a key's segments */
export function sampleKey(segs, step) {
  const out = [];
  for (let i = 0; i + 3 < segs.length; i += 4) {
    const ax = segs[i], ay = segs[i + 1], dx = segs[i + 2] - ax, dy = segs[i + 3] - ay;
    const n = Math.floor(Math.hypot(dx, dy) / step) + 1;
    for (let k = 0; k < n; k++) out.push(ax + (dx * k) / n, ay + (dy * k) / n);
  }
  return out;
}

export function pointInPoly(x, y, poly) {
  let ins = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[j];
    if (y1 > y !== y2 > y && x < ((x2 - x1) * (y - y1)) / (y2 - y1) + x1) ins = !ins;
  }
  return ins;
}
