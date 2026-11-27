// GPU side of the in-browser georeferencer (WebGPU compute):
//  * corridor score: metres of modern street centreline that fall in a printed street corridor
//    (a printed street is a band of white between building ink);
//  * label hits: labels within 8 m of their own street, per transform;
//  * pair search: every placement implied by putting two labels on points of their two streets,
//    scored by how many of all the labels then land on their own streets.
const WG = 256;

const SHADER = /* wgsl */ `
struct Meta { W: u32, H: u32, nPts: u32, nT: u32, f: f32, pad0: f32, pad1: f32, pad2: f32 };
@group(0) @binding(0) var<uniform> M: Meta;
@group(0) @binding(1) var<storage, read> ink: array<u32>;   // bytes packed 4 per u32
@group(0) @binding(2) var<storage, read> mask: array<u32>;
@group(0) @binding(3) var<storage, read> dt: array<f32>;
@group(0) @binding(4) var<storage, read> pts: array<vec4<f32>>;
@group(0) @binding(5) var<storage, read> Ts: array<vec4<f32>>; // (s, th, tx, ty)
@group(0) @binding(6) var<storage, read_write> acc: array<atomic<u32>>; // 4 per transform: good, bad, rg, rb

var<workgroup> wsum: array<atomic<u32>, 4>;

fn byteAt(buf: ptr<storage, array<u32>, read>, i: u32) -> u32 {
  return ((*buf)[i >> 2u] >> ((i & 3u) * 8u)) & 0xffu;
}
fn inkAt(x: i32, y: i32) -> bool { return byteAt(&ink, u32(y) * M.W + u32(x)) != 0u; }
fn maskAt(x: i32, y: i32) -> bool { return byteAt(&mask, u32(y) * M.W + u32(x)) != 0u; }

// first offset (m) along n with ink, 99 if none; known = probe's far end still inside the part
fn probe(p: vec2<f32>, n: vec2<f32>, mpp: f32, known: ptr<function, bool>) -> f32 {
  let Wi = i32(M.W) - 1; let Hi = i32(M.H) - 1;
  let e = round(p + (25.5 / mpp) * n); // the probe's far end: still inside the part?
  *known = *known && maskAt(clamp(i32(e.x), 0, Wi), clamp(i32(e.y), 0, Hi));
  for (var k = 0; k < 50; k++) {
    let off = 1.0 + 0.5 * f32(k);
    let q = round(p + (off / mpp) * n);
    if (inkAt(clamp(i32(q.x), 0, Wi), clamp(i32(q.y), 0, Hi))) { return off; }
  }
  return 99.0;
}

@compute @workgroup_size(${WG})
fn main(@builtin(global_invocation_id) gid: vec3<u32>, @builtin(local_invocation_index) li: u32,
        @builtin(workgroup_id) wid: vec3<u32>) {
  if (li < 4u) { atomicStore(&wsum[li], 0u); }
  workgroupBarrier();
  let i = gid.x;
  let j = wid.y;
  var kind = 4u; // 0 good, 1 bad, 2 rail good, 3 rail bad, 4 nothing
  if (i < M.nPts && j < M.nT) {
    let T = Ts[j]; let P = pts[i];
    let c = cos(T.y); let s = sin(T.y);
    let v = P.xy - T.zw;
    let q = vec2<f32>(v.x * c + v.y * s, -v.x * s + v.y * c) / T.x;
    let p = vec2<f32>(q.x, -q.y) * M.f;
    let pi = round(p);
    let x = i32(pi.x); let y = i32(pi.y);
    if (x >= 0 && x < i32(M.W) && y >= 0 && y < i32(M.H) && maskAt(x, y)) {
      let mpp = T.x / M.f;
      let d = dt[u32(y) * M.W + u32(x)] * mpp;
      if (P.z > 5.0) {
        kind = select(3u, 2u, d <= 3.0);
      } else {
        let n0 = vec2<f32>(P.z * c + P.w * s, -P.z * s + P.w * c);
        let n = vec2<f32>(n0.x, -n0.y);
        var known = true;
        let a = probe(p, n, mpp, &known);
        let b = probe(p, -n, mpp, &known);
        let w = a + b;
        if (known) {
          let good = d >= 2.5 && a < 90.0 && b < 90.0 && w >= 9.0 && w <= 36.0;
          kind = select(1u, 0u, good);
        }
      }
    }
  }
  if (kind < 4u) { atomicAdd(&wsum[kind], 1u); }
  workgroupBarrier();
  if (li < 4u) {
    let v = atomicLoad(&wsum[li]);
    if (v > 0u) { atomicAdd(&acc[j * 4u + li], v); }
  }
}`;

// labels on their own street (within 8 m) per transform: one invocation per (label, transform)
const LABEL_SHADER = /* wgsl */ `
@group(0) @binding(0) var<storage, read> labels: array<vec4<f32>>; // px, py, first seg, n segs
@group(0) @binding(1) var<storage, read> segs: array<vec4<f32>>;
@group(0) @binding(2) var<storage, read> Ts: array<vec4<f32>>;
@group(0) @binding(3) var<storage, read_write> hits: array<atomic<u32>>;
@group(0) @binding(4) var<uniform> N: vec4<u32>; // nLabels, nT
@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid: vec3<u32>) {
  let i = gid.x; let j = gid.y + gid.z * 65535u;
  if (i >= N.x || j >= N.y) { return; }
  let T = Ts[j]; let L = labels[i];
  let c = cos(T.y); let s = sin(T.y);
  let w = T.x * vec2<f32>(c * L.x + s * L.y, s * L.x - c * L.y) + T.zw;
  var best = 1e9;
  for (var k = u32(L.z); k < u32(L.z) + u32(L.w); k++) {
    let S = segs[k]; let d = S.zw - S.xy;
    let u = clamp(dot(w - S.xy, d) / max(dot(d, d), 1e-9), 0.0, 1.0);
    best = min(best, length(w - (S.xy + u * d)));
  }
  if (best <= 8.0) { atomicAdd(&hits[j], 1u); }
}`;

// One invocation per candidate (label pair p, sample a on label i's street, sample b on label j's):
// the similarity putting label i at a and label j at b; hits = labels within tol of their street.
// Per workgroup, the best candidate as (hits << 8 | local index).
const SEARCH_SHADER = /* wgsl */ `
struct P { nCand: u32, nPairs: u32, nLabels: u32, nx: u32, smin: f32, smax: f32, tol: f32, pad: f32 };
@group(0) @binding(0) var<uniform> U: P;
@group(0) @binding(1) var<storage, read> pairs: array<vec4<u32>>;   // i, j, first candidate, nB
@group(0) @binding(2) var<storage, read> labels: array<vec4<f32>>;  // u, v, first seg, n segs
@group(0) @binding(3) var<storage, read> segs: array<vec4<f32>>;
@group(0) @binding(4) var<storage, read> samp: array<vec2<f32>>;
@group(0) @binding(5) var<storage, read> labSamp: array<vec2<u32>>; // first sample, n samples
@group(0) @binding(6) var<storage, read_write> best: array<u32>;
var<workgroup> wbest: atomic<u32>;

@compute @workgroup_size(256)
fn main(@builtin(local_invocation_index) li: u32, @builtin(workgroup_id) wid: vec3<u32>) {
  if (li == 0u) { atomicStore(&wbest, 0u); }
  workgroupBarrier();
  let w = wid.y * U.nx + wid.x;
  let g = w * 256u + li;
  if (g < U.nCand) {
    var lo = 0u; var hi = U.nPairs - 1u;
    while (lo < hi) { let m = (lo + hi + 1u) / 2u; if (pairs[m].z <= g) { lo = m; } else { hi = m - 1u; } }
    let pr = pairs[lo]; let r = g - pr.z; let a = r / pr.w; let b = r % pr.w;
    let Li = labels[pr.x]; let Lj = labels[pr.y];
    let A = samp[labSamp[pr.x].x + a]; let B = samp[labSamp[pr.y].x + b];
    let dc = vec2<f32>(Lj.x - Li.x, -(Lj.y - Li.y));
    let dw = B - A;
    let s = length(dw) / length(dc);
    if (s >= U.smin && s <= U.smax) {
      let th = atan2(dw.y, dw.x) - atan2(dc.y, dc.x);
      let c = cos(th); let n = sin(th);
      let t = A - s * vec2<f32>(c * Li.x + n * Li.y, n * Li.x - c * Li.y);
      var hits = 0u;
      for (var k = 0u; k < U.nLabels; k++) {
        let L = labels[k];
        let p = s * vec2<f32>(c * L.x + n * L.y, n * L.x - c * L.y) + t;
        var d2 = 1e18;
        for (var q = u32(L.z); q < u32(L.z) + u32(L.w); q++) {
          let S = segs[q]; let e = S.zw - S.xy;
          let u = clamp(dot(p - S.xy, e) / max(dot(e, e), 1e-9), 0.0, 1.0);
          let f = p - (S.xy + u * e);
          d2 = min(d2, dot(f, f));
        }
        if (d2 <= U.tol * U.tol) { hits++; }
      }
      atomicMax(&wbest, (min(hits, 255u) << 8u) | li);
    }
  }
  workgroupBarrier();
  if (li == 0u) { best[w] = atomicLoad(&wbest); }
}`;

export async function gpuDevice() {
  if (!navigator.gpu) throw new Error("This browser has no WebGPU.");
  const adapter = await navigator.gpu.requestAdapter({ powerPreference: "high-performance" });
  if (!adapter) throw new Error("No WebGPU adapter.");
  const device = await adapter.requestDevice({
    requiredLimits: {
      maxStorageBufferBindingSize: adapter.limits.maxStorageBufferBindingSize,
      maxBufferSize: adapter.limits.maxBufferSize,
    },
  });
  const info = adapter.info || {};
  return { device, info: { vendor: info.vendor, architecture: info.architecture, fallback: !!info.isFallbackAdapter } };
}

async function pipelineFor(device, code) {
  const module = device.createShaderModule({ code });
  const ci = await module.getCompilationInfo();
  for (const m of ci.messages) if (m.type === "error") throw new Error(`WGSL: ${m.message} @${m.lineNum}`);
  return device.createComputePipeline({ layout: "auto", compute: { module, entryPoint: "main" } });
}

const bufferOf = (device, data, usage) => {
  const size = Math.max(16, Math.ceil(data.byteLength / 4) * 4);
  const b = device.createBuffer({ size, usage, mappedAtCreation: true });
  new Uint8Array(b.getMappedRange()).set(new Uint8Array(data.buffer, data.byteOffset, data.byteLength));
  b.unmap();
  return b;
};

async function readBack(device, src, bytes) {
  const r = device.createBuffer({ size: bytes, usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST });
  const enc = device.createCommandEncoder();
  enc.copyBufferToBuffer(src, 0, r, 0, bytes);
  device.queue.submit([enc.finish()]);
  await r.mapAsync(GPUMapMode.READ);
  const out = new Uint32Array(r.getMappedRange().slice(0));
  r.unmap(); r.destroy();
  return out;
}

/** labs: [{u, v, segs}] -> packed labels (u, v, first seg, n segs) and segments */
function packLabels(labs) {
  const L = [], S = [];
  for (const l of labs) {
    L.push(l.u, l.v, S.length / 4, l.segs.length / 4);
    for (const x of l.segs) S.push(x);
  }
  return { labels: new Float32Array(L.length ? L : [0, 0, 0, 0]), segs: new Float32Array(S.length ? S : [0, 0, 0, 0]) };
}

/** sheet: prepareSheet() output; pts: samplePoints(); labs: targetedLabels() */
export async function makeGpu({ device, info }, sheet, pts, labs) {
  const ST = GPUBufferUsage.STORAGE;
  const u8 = (a) => bufferOf(device, a, ST);
  const bInk = u8(sheet.ink), bMask = u8(sheet.mask), bDt = bufferOf(device, sheet.dt, ST);
  const corr = await pipelineFor(device, SHADER);
  const lab = await pipelineFor(device, LABEL_SHADER);
  const search = await pipelineFor(device, SEARCH_SHADER);
  const packed = packLabels(labs);
  const bLab = bufferOf(device, packed.labels, ST), bSeg = bufferOf(device, packed.segs, ST);

  function near(x, y, r) {
    const keep = [];
    for (let i = 0; i < pts.length; i += 4) {
      const dx = pts[i] - x, dy = pts[i + 1] - y;
      if (dx * dx + dy * dy <= r * r) keep.push(pts[i], pts[i + 1], pts[i + 2], pts[i + 3]);
    }
    return new Float32Array(keep);
  }

  /** corridor (good, bad) metres for each T, all near world point region {x, y, r} */
  async function corridor(Ts, region) {
    const sub = near(region.x, region.y, region.r), nPts = sub.length / 4;
    if (!nPts) return Ts.map(() => [0, 0]);
    const bPts = bufferOf(device, sub, ST), out = [];
    for (let o = 0; o < Ts.length; o += 65535) {
      const chunk = Ts.slice(o, o + 65535), nT = chunk.length;
      const mt = new ArrayBuffer(32), dv = new DataView(mt);
      dv.setUint32(0, sheet.W, true); dv.setUint32(4, sheet.H, true); dv.setUint32(8, nPts, true);
      dv.setUint32(12, nT, true); dv.setFloat32(16, sheet.f, true);
      const bMeta = bufferOf(device, new Uint8Array(mt), GPUBufferUsage.UNIFORM);
      const bT = bufferOf(device, new Float32Array(chunk.flat()), ST);
      const bAcc = device.createBuffer({ size: nT * 16, usage: ST | GPUBufferUsage.COPY_SRC });
      const bind = device.createBindGroup({
        layout: corr.getBindGroupLayout(0),
        entries: [bMeta, bInk, bMask, bDt, bPts, bT, bAcc].map((b, k) => ({ binding: k, resource: { buffer: b } })),
      });
      const enc = device.createCommandEncoder(), pass = enc.beginComputePass();
      pass.setPipeline(corr); pass.setBindGroup(0, bind);
      pass.dispatchWorkgroups(Math.ceil(nPts / WG), nT);
      pass.end(); device.queue.submit([enc.finish()]);
      const a = await readBack(device, bAcc, nT * 16);
      for (let k = 0; k < nT; k++) out.push([3 * (a[4 * k] + 2 * a[4 * k + 2]), 3 * (a[4 * k + 1] + 2 * a[4 * k + 3])]);
      [bMeta, bT, bAcc].forEach((b) => b.destroy());
    }
    bPts.destroy();
    return out;
  }

  /** labels within 8 m of their own street, per T */
  async function labelHits(Ts) {
    const nL = labs.length, nT = Ts.length;
    if (!nL) return new Array(nT).fill(0);
    const bT = bufferOf(device, new Float32Array(Ts.flat()), ST);
    const bH = device.createBuffer({ size: Math.max(16, nT * 4), usage: ST | GPUBufferUsage.COPY_SRC });
    const bN = bufferOf(device, new Uint32Array([nL, nT, 0, 0]), GPUBufferUsage.UNIFORM);
    const bind = device.createBindGroup({ layout: lab.getBindGroupLayout(0),
      entries: [bLab, bSeg, bT, bH, bN].map((b, k) => ({ binding: k, resource: { buffer: b } })) });
    const enc = device.createCommandEncoder(), pass = enc.beginComputePass();
    pass.setPipeline(lab); pass.setBindGroup(0, bind);
    pass.dispatchWorkgroups(Math.ceil(nL / 64), Math.min(nT, 65535), Math.ceil(nT / 65535));
    pass.end(); device.queue.submit([enc.finish()]);
    const h = Array.from(await readBack(device, bH, nT * 4));
    [bT, bH, bN].forEach((b) => b.destroy());
    return h;
  }

  /** pair search. pairs: [[i, j]] into labs; samples: per label {start, count} into samp (vec2s).
   *  -> per workgroup best (hits << 8 | lane) and the candidate layout to decode it */
  async function pairSearch(pairs, samp, labSamp, { smin, smax, tol }) {
    const P = [];
    let n = 0;
    for (const [i, j] of pairs) { P.push(i, j, n, labSamp[j].count); n += labSamp[i].count * labSamp[j].count; }
    const nWG = Math.ceil(n / 256), nx = Math.min(nWG, 65535), ny = Math.ceil(nWG / nx);
    const ub = new ArrayBuffer(32), dv = new DataView(ub);
    dv.setUint32(0, n, true); dv.setUint32(4, pairs.length, true); dv.setUint32(8, labs.length, true);
    dv.setUint32(12, nx, true); dv.setFloat32(16, smin, true); dv.setFloat32(20, smax, true); dv.setFloat32(24, tol, true);
    const bU = bufferOf(device, new Uint8Array(ub), GPUBufferUsage.UNIFORM);
    const bP = bufferOf(device, new Uint32Array(P), ST);
    const bS = bufferOf(device, new Float32Array(samp), ST);
    const bLS = bufferOf(device, new Uint32Array(labSamp.flatMap((x) => [x.start, x.count])), ST);
    const bB = device.createBuffer({ size: Math.max(16, nx * ny * 4), usage: ST | GPUBufferUsage.COPY_SRC });
    const bind = device.createBindGroup({ layout: search.getBindGroupLayout(0),
      entries: [bU, bP, bLab, bSeg, bS, bLS, bB].map((b, k) => ({ binding: k, resource: { buffer: b } })) });
    const enc = device.createCommandEncoder(), pass = enc.beginComputePass();
    pass.setPipeline(search); pass.setBindGroup(0, bind);
    pass.dispatchWorkgroups(nx, ny);
    pass.end(); device.queue.submit([enc.finish()]);
    const best = await readBack(device, bB, nx * ny * 4);
    [bU, bP, bS, bLS, bB].forEach((b) => b.destroy());
    return { best, layout: P, nCand: n };
  }

  const destroy = () => [bInk, bMask, bDt, bLab, bSeg].forEach((b) => b.destroy());
  return { info, corridor, labelHits, pairSearch, destroy };
}
