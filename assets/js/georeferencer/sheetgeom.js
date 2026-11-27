// The sheet's neatline (printed border) and its parts (areas split by heavy rules), on
// OpenCV.js. Images: {w, h, d: RGBA}. Results in canvas pixels.

// OpenCV.js's module object is a thenable that resolves to itself; resolving a promise with it
// loops forever, so it travels wrapped in {cv}
let cvReady = null;
export function loadCv() {
  cvReady ||= import("@techstark/opencv-js").then(
    (mod) =>
      new Promise((resolve) => {
        const cv = mod.default || mod;
        const poll = () => (cv.Mat ? resolve({ cv }) : setTimeout(poll, 20));
        poll();
      }),
  );
  return cvReady; // resolves to {cv}: never return cv itself from an async function
}

// Mats created inside fn are deleted when it returns
function scoped(cv, fn) {
  const made = [];
  const M = (m) => (made.push(m), m);
  try { return fn(M); } finally { for (const m of made) if (!m.isDeleted()) m.delete(); }
}

const rgbaMat = (cv, img) => cv.matFromImageData({ width: img.w, height: img.h, data: img.d });

// ---- neatline -------------------------------------------------------------------------------

const BAND = 0.085, MIN_LEN = 0.45, MAX_TILT = (3 * Math.PI) / 180, MARGIN_INK = 0.02, CONTENT_START = 0.01;

function houghSegs(cv, M, bin, theta, thr, minLen, gap) {
  const lines = M(new cv.Mat());
  cv.HoughLinesP(bin, lines, 1, theta, thr, minLen, gap);
  const out = [];
  const L = lines.data32S;
  for (let i = 0; i < lines.rows; i++) out.push([L[4 * i], L[4 * i + 1], L[4 * i + 2], L[4 * i + 3]]);
  return out;
}

function mergeLines(lines, horizontal, L) {
  const groups = [];
  for (const [x1, y1, x2, y2] of lines) {
    const off = horizontal ? (y1 + y2) / 2 : (x1 + x2) / 2;
    const span = horizontal ? [Math.min(x1, x2), Math.max(x1, x2)] : [Math.min(y1, y2), Math.max(y1, y2)];
    const g = groups.find((g) => Math.abs(g.off - off) <= 4);
    if (g) { g.spans.push(span); g.segs.push([x1, y1, x2, y2]); }
    else groups.push({ off, spans: [span], segs: [[x1, y1, x2, y2]] });
  }
  for (const g of groups) {
    let cov = 0, end = -1;
    for (const [a, b] of g.spans.slice().sort((p, q) => p[0] - q[0] || p[1] - q[1])) if (b > end) { cov += b - Math.max(a, end); end = b; }
    g.cov = cov / L;
  }
  return groups.filter((g) => g.cov >= MIN_LEN);
}

function fitLine(cv, M, segs) {
  const pts = segs.flatMap(([x1, y1, x2, y2]) => [x1, y1, x2, y2]);
  const mat = M(cv.matFromArray(pts.length / 2, 1, cv.CV_32FC2, pts)), line = M(new cv.Mat());
  cv.fitLine(mat, line, cv.DIST_L2, 0, 0.01, 0.01);
  const [vx, vy, x0, y0] = line.data32F;
  return [x0, y0, vx, vy];
}

function intersect([x1, y1, dx1, dy1], [x2, y2, dx2, dy2]) {
  const d = dx1 * dy2 - dy1 * dx2, t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / d;
  return [x1 + t * dx1, y1 + t * dy1];
}

/** the neatline, found on the overview (!1536 px) -> 4 corners (TL, TR, BR, BL) in canvas px,
 *  or the whole canvas when the border found covers less than half of it */
export async function neatline(img, canvasW, canvasH) {
  const { cv } = await loadCv();
  const corners = scoped(cv, (M) => {
    const rgba = M(rgbaMat(cv, img)), gray = M(new cv.Mat()), rgb = M(new cv.Mat()), hsv = M(new cv.Mat());
    cv.cvtColor(rgba, gray, cv.COLOR_RGBA2GRAY);
    cv.cvtColor(rgba, rgb, cv.COLOR_RGBA2RGB);
    cv.cvtColor(rgb, hsv, cv.COLOR_RGB2HSV);
    const w = img.w, h = img.h, n = w * h;
    const bg = M(new cv.Mat());
    cv.medianBlur(gray, bg, 41);
    // copies: OpenCV.js's heap grows as Mats are made, detaching earlier typed-array views
    const g = gray.data.slice(), b = bg.data.slice(), sat = hsv.data.slice(), dk = new Uint8Array(n);
    for (let i = 0; i < n; i++) dk[i] = b[i] - g[i] > 35 || g[i] < 90 ? 1 : 0;
    const dark = M(cv.matFromArray(h, w, cv.CV_8UC1, dk));
    const opened = M(new cv.Mat()), thick = M(new cv.Mat());
    cv.morphologyEx(dark, opened, cv.MORPH_OPEN, M(cv.Mat.ones(9, 9, cv.CV_8U)));
    cv.dilate(opened, thick, M(cv.Mat.ones(5, 5, cv.CV_8U)));
    const th = thick.data.slice(), thin = new Uint8Array(n), content = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      thin[i] = dk[i] & (1 - th[i]);
      content[i] = Math.max(thin[i], sat[3 * i + 1] > 90 ? 1 - th[i] : 0);
    }
    const edges = { top: [0, 0, 1, 0], bottom: [0, h - 1, 1, 0], left: [0, 0, 0, 1], right: [w - 1, 0, 0, 1] };
    const found = {};
    for (const side of ["top", "bottom", "left", "right"]) {
      const horizontal = side === "top" || side === "bottom";
      const L = horizontal ? w : h, D = horizontal ? h : w, bb = Math.trunc(BAND * D);
      const band = M(new cv.Mat(h, w, cv.CV_8UC1, new cv.Scalar(0))), bd = band.data;
      for (let y = 0; y < h; y++)
        for (let x = 0; x < w; x++) {
          const inBand = side === "top" ? y < bb : side === "bottom" ? y >= h - bb : side === "left" ? x < bb : x >= w - bb;
          if (inBand) bd[y * w + x] = thin[y * w + x] * 255;
        }
      const segs = houghSegs(cv, M, band, Math.PI / 720, Math.trunc(0.15 * L), Math.trunc(0.1 * L), Math.trunc(0.02 * L))
        .filter(([x1, y1, x2, y2]) => {
          const a = Math.atan2(y2 - y1, x2 - x1), tilt = horizontal ? Math.abs(Math.sin(a)) : Math.abs(Math.cos(a));
          return tilt <= Math.sin(MAX_TILT);
        });
      const marginOk = (gr) => {
        const o = Math.round(gr.off);
        let s = 0, c = 0;
        const add = (x0, x1, y0, y1) => { for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) { s += content[y * w + x]; c++; } };
        if (side === "top") add(0, w, 0, Math.max(o - 6, 0));
        else if (side === "bottom") add(0, w, Math.min(o + 7, h), h);
        else if (side === "left") add(0, Math.max(o - 6, 0), 0, h);
        else add(Math.min(o + 7, w), w, 0, h);
        return c === 0 || s / c < MARGIN_INK;
      };
      const groups = mergeLines(segs, horizontal, L).filter(marginOk);
      if (!groups.length) {
        // no ruled border: trim blank paper up to where the drawing starts
        const prof = new Float64Array(D);
        for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) prof[horizontal ? y : x] += content[y * w + x];
        for (let i = 0; i < D; i++) prof[i] /= L;
        const win = Math.max(3, Math.trunc(0.01 * D)), sm = new Float64Array(D);
        // np.convolve(mode="same") with a box of `win`
        const left = Math.floor((win - 1) / 2);
        for (let i = 0; i < D; i++) { let s = 0; for (let j = 0; j < win; j++) { const k = i - left + j; if (k >= 0 && k < D) s += prof[k]; } sm[i] = s / win; }
        const nb = Math.trunc(BAND * D), idx = [];
        if (side === "top" || side === "left") for (let i = 0; i < nb; i++) idx.push(i);
        else for (let i = D - 1; i > D - 1 - nb; i--) idx.push(i);
        const start = idx.find((i) => sm[i] > CONTENT_START);
        if (start === undefined) continue;
        const pad = Math.trunc(0.005 * D);
        const off = side === "top" || side === "left" ? Math.max(start - pad, 0) : Math.min(start + pad, D - 1);
        found[side] = horizontal ? [0, off, 1, 0] : [off, 0, 0, 1];
        continue;
      }
      const outer = side === "top" || side === "left"
        ? groups.reduce((a, c) => (c.off < a.off ? c : a)) : groups.reduce((a, c) => (c.off > a.off ? c : a));
      found[side] = fitLine(cv, M, outer.segs);
    }
    const ln = (s) => found[s] || edges[s];
    return [intersect(ln("top"), ln("left")), intersect(ln("top"), ln("right")), intersect(ln("bottom"), ln("right")), intersect(ln("bottom"), ln("left"))]
      .map(([x, y]) => [Math.min(Math.max(x, 0), w - 1), Math.min(Math.max(y, 0), h - 1)]);
  });
  const k = canvasW / img.w, pts = corners.map(([x, y]) => [x * k, y * k]);
  const full = [[0, 0], [canvasW, 0], [canvasW, canvasH], [0, canvasH]];
  return polyArea(pts) > 0.5 * canvasW * canvasH ? pts : full;
}

function polyArea(p) {
  let a = 0;
  for (let i = 0; i < p.length; i++) { const [x1, y1] = p[i], [x2, y2] = p[(i + 1) % p.length]; a += x1 * y2 - x2 * y1; }
  return Math.abs(a) / 2;
}

// ---- parts ------------------------------------------------------------------------------------

const MIN_PART = 0.03;

/** parts, split along heavy rules on the !2000 px image: part polygons in canvas px, largest first (else [neat]) */
export async function splitParts(img, canvasW, canvasH, neat) {
  const { cv } = await loadCv();
  const parts = scoped(cv, (M) => {
    const rgba = M(rgbaMat(cv, img)), gray = M(new cv.Mat());
    cv.cvtColor(rgba, gray, cv.COLOR_RGBA2GRAY);
    const w = img.w, h = img.h, n = w * h, s = w / canvasW, L = Math.max(w, h);
    const g = gray.data.slice(), inkA = new Uint8Array(n);
    for (let i = 0; i < n; i++) inkA[i] = g[i] < 140 ? 1 : 0;
    const ink = M(cv.matFromArray(h, w, cv.CV_8UC1, inkA));
    const k = Math.max(3, Math.round(21 * s));
    const ell = (sz) => M(cv.getStructuringElement(cv.MORPH_ELLIPSE, new cv.Size(sz, sz)));
    const heavy = M(new cv.Mat());
    cv.morphologyEx(ink, heavy, cv.MORPH_OPEN, ell(k));
    const heavy255 = M(new cv.Mat());
    heavy.convertTo(heavy255, cv.CV_8U, 255);
    const segs = houghSegs(cv, M, heavy255, Math.PI / 360, Math.trunc(0.05 * L), Math.trunc(0.12 * L), Math.trunc(0.06 * L));
    const rules = M(new cv.Mat(h, w, cv.CV_8UC1, new cv.Scalar(0)));
    const line = (x1, y1, x2, y2) => cv.line(rules, new cv.Point(Math.trunc(x1), Math.trunc(y1)), new cv.Point(Math.trunc(x2), Math.trunc(y2)), new cv.Scalar(1), k);
    for (const [x1, y1, x2, y2] of segs) line(x1, y1, x2, y2);
    // join two in-line rule segments across a gap (a compass rose or label over the rule)
    const dir = (x1, y1, x2, y2) => { const d = Math.hypot(x2 - x1, y2 - y1); return d ? [(x2 - x1) / d, (y2 - y1) / d] : [0, 0]; };
    const aligned = (u, v, tol = 0.97) => Math.abs(u[0] * v[0] + u[1] * v[1]) >= tol;
    for (let i = 0; i < segs.length; i++) {
      const a = segs[i], da = dir(...a);
      for (const b of segs.slice(i + 1)) {
        const db = dir(...b);
        if (!aligned(da, db, 0.95)) continue;
        for (const p of [[a[0], a[1]], [a[2], a[3]]])
          for (const q of [[b[0], b[1]], [b[2], b[3]]]) {
            const gap = Math.hypot(q[0] - p[0], q[1] - p[1]);
            const la = Math.hypot(a[2] - a[0], a[3] - a[1]), lb = Math.hypot(b[2] - b[0], b[3] - b[1]);
            const off = Math.abs((q[0] - p[0]) * da[1] - (q[1] - p[1]) * da[0]);
            const maxGap = Math.min(la, lb) >= 0.12 * L && off < 2 * k ? 0.25 * L : 0.1 * L;
            if (0.01 * L < gap && gap < maxGap && aligned(dir(p[0], p[1], q[0], q[1]), da)) line(p[0], p[1], q[0], q[1]);
          }
      }
    }
    const page = M(new cv.Mat(h, w, cv.CV_8UC1, new cv.Scalar(0)));
    const neatPx = M(cv.matFromArray(neat.length, 1, cv.CV_32SC2, neat.flatMap(([x, y]) => [Math.trunc(x * s), Math.trunc(y * s)])));
    const pv = M(new cv.MatVector()); pv.push_back(neatPx);
    cv.fillPoly(page, pv, new cv.Scalar(1));
    const m = Math.trunc(0.025 * L), rect = M(cv.getStructuringElement(cv.MORPH_RECT, new cv.Size(2 * m + 1, 2 * m + 1)));
    const inner = M(new cv.Mat());
    cv.erode(page, inner, rect, new cv.Point(-1, -1), 1, cv.BORDER_CONSTANT, new cv.Scalar(0));
    const rulesD = M(new cv.Mat());
    cv.dilate(rules, rulesD, ell(k));
    // heavy ink touching a found rule (the short jog between two parallel rules)
    const hl = M(new cv.Mat()), nh = cv.connectedComponents(heavy, hl);
    const touch = new Uint8Array(nh), hld = hl.data32S.slice(), rd = rulesD.data.slice(), hd = heavy.data.slice();
    for (let i = 0; i < n; i++) if (rd[i] && hd[i] && hld[i] > 0) touch[hld[i]] = 1;
    const tmA = new Uint8Array(n);
    for (let i = 0; i < n; i++) tmA[i] = touch[hld[i]] && hld[i] > 0 ? 1 : 0;
    const tm = M(cv.matFromArray(h, w, cv.CV_8UC1, tmA));
    const tmD = M(new cv.Mat());
    cv.dilate(tm, tmD, ell(k));
    const tmd = tmD.data.slice(), inn = inner.data.slice(), freeA = new Uint8Array(n);
    for (let i = 0; i < n; i++) freeA[i] = inn[i] & (rd[i] || tmd[i] ? 0 : 1);
    const free = M(cv.matFromArray(h, w, cv.CV_8UC1, freeA));
    const lab = M(new cv.Mat()), stats = M(new cv.Mat()), cents = M(new cv.Mat());
    const nl = cv.connectedComponentsWithStats(free, lab, stats, cents, 4);
    const pageA = page.data.slice();
    let pageSum = 0;
    for (let i = 0; i < n; i++) pageSum += pageA[i];
    const sd = stats.data32S.slice(), area = (i) => sd[i * stats.cols + cv.CC_STAT_AREA];
    const big = [];
    for (let i = 1; i < nl; i++) if (area(i) >= MIN_PART * pageSum) big.push(i);
    const ld = lab.data32S.slice(), isBig = new Uint8Array(nl);
    big.forEach((i) => (isBig[i] = 1));
    let nearest;
    if (big.length > 1) {
      const nbA = new Uint8Array(n);
      for (let i = 0; i < n; i++) nbA[i] = isBig[ld[i]] ? 0 : 1;
      const notBig = M(cv.matFromArray(h, w, cv.CV_8UC1, nbA));
      const dist = M(new cv.Mat()), nearPx = M(new cv.Mat());
      cv.distanceTransformWithLabels(notBig, dist, nearPx, cv.DIST_L2, 5, cv.DIST_LABEL_PIXEL);
      const np_ = nearPx.data32S.slice();
      let mx = 0;
      for (let i = 0; i < n; i++) if (np_[i] > mx) mx = np_[i];
      const ids = new Int32Array(mx + 1);
      for (let i = 0; i < n; i++) if (isBig[ld[i]]) ids[np_[i]] = ld[i];
      nearest = new Int32Array(n);
      for (let i = 0; i < n; i++) nearest[i] = ids[np_[i]];
    } else {
      nearest = new Int32Array(n).fill(big.length ? big[0] : 0);
    }
    const out = [];
    const order = [];
    for (let i = 1; i < nl; i++) order.push(i);
    order.sort((a, b) => area(b) - area(a));
    for (const i of order) {
      if (area(i) < MIN_PART * pageSum) continue;
      const regA = new Uint8Array(n);
      for (let p = 0; p < n; p++) regA[p] = ld[p] === i ? 1 : 0;
      const region = M(cv.matFromArray(h, w, cv.CV_8UC1, regA)), dil = M(new cv.Mat());
      cv.dilate(region, dil, rect);
      const dA = dil.data.slice();
      for (let p = 0; p < n; p++) dA[p] = dA[p] & pageA[p] & (nearest[p] === i ? 1 : 0);
      const grown = M(cv.matFromArray(h, w, cv.CV_8UC1, dA));
      const closed = M(new cv.Mat());
      cv.morphologyEx(grown, closed, cv.MORPH_CLOSE, ell(k * 2));
      const cs = M(new cv.MatVector()), hier = M(new cv.Mat());
      cv.findContours(closed, cs, hier, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      let best = null, ba = -1;
      for (let c = 0; c < cs.size(); c++) { const ct = M(cs.get(c)), a = cv.contourArea(ct); if (a > ba) { ba = a; best = ct; } }
      if (!best) continue;
      const approx = M(new cv.Mat());
      cv.approxPolyDP(best, approx, 0.004 * L, true);
      const pts = [];
      const ad = approx.data32S;
      for (let r = 0; r < approx.rows; r++) pts.push([ad[2 * r] / s, ad[2 * r + 1] / s]);
      out.push(pts);
    }
    return out;
  });
  return parts.length ? parts : [neat];
}
