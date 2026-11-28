// Volunteer page hook: keeps a Web Worker (js/georeferencer/worker.js) busy with jobs from the queue
// while the page is open, and draws finished sheets on a map as they arrive from anyone.
import L from "leaflet";
import { fwd, fromAB } from "./engine";

const WAIT_EMPTY_MS = 30000;

function css(href) {
  if (document.querySelector(`link[href="${href}"]`)) return;
  const l = document.createElement("link");
  l.rel = "stylesheet"; l.href = href;
  document.head.appendChild(l);
}

// A sheet image placed on the map by an affine transform (canvas px -> map), clipped to its part.
const SheetOverlay = L.Layer.extend({
  initialize(item, part) { this.item = item; this.part = part; },
  onAdd(map) {
    const it = this.item, k = 600 / Math.max(it.width, it.height);
    this.k = k;
    const img = (this.img = L.DomUtil.create("img", "leaflet-zoom-hide"));
    img.src = `${it.service}/full/!600,600/0/default.jpg`;
    // maxWidth/height: the site's base styles shrink images to their (zero-width) pane
    Object.assign(img.style, { position: "absolute", left: "0", top: "0", transformOrigin: "0 0", opacity: "0", transition: "opacity 1.2s",
      maxWidth: "none", height: "auto", display: "block",
      clipPath: `polygon(${this.part.mask.map(([u, v]) => `${u * k}px ${v * k}px`).join(",")})`, pointerEvents: "none" });
    img.onload = () => { img.style.opacity = "0.85"; this.place(); };
    map.getPanes().overlayPane.appendChild(img);
    map.on("zoom viewreset move", this.place, this);
    this.place();
  },
  onRemove(map) { this.img.remove(); map.off("zoom viewreset move", this.place, this); },
  place() {
    if (!this._map || !this.img.naturalWidth) return;
    const m = this._map, [c0, c1, c2] = this.part.corners.map(([lon, lat]) => m.latLngToLayerPoint([lat, lon]));
    // canvas (0,0),(1000,0),(0,1000) -> c0,c1,c2; image px = canvas px * k
    const s = 1 / (1000 * this.k);
    const a = (c1.x - c0.x) * s, b = (c1.y - c0.y) * s, c = (c2.x - c0.x) * s, d = (c2.y - c0.y) * s;
    this.img.style.transform = `matrix(${a},${b},${c},${d},${c0.x},${c0.y})`;
  },
});

export const GeorefVolunteer = {
  mounted() {
    css("/georeferencer/ocr/leaflet.css");
    this.el.innerHTML = `
      <section class="border border-sage-300 bg-white p-3 text-sm flex flex-col gap-2">
        <div class="flex items-center gap-2">
          <span data-role="dot" class="inline-block w-3 h-3 rounded-full bg-stone-400"></span>
          <b data-role="state">Starting…</b>
          <span class="grow"></span>
          <button data-role="toggle" class="btn-secondary px-3 py-1">Pause</button>
        </div>
        <div data-role="job" class="min-h-[1.25rem]"></div>
        <div data-role="step" class="text-xs text-stone-600 min-h-[1rem]"></div>
        <div class="relative">
          <img data-role="thumb" class="block w-full hidden" alt="">
          <canvas data-role="marks" class="absolute inset-0 w-full h-full pointer-events-none"></canvas>
        </div>
        <div data-role="mine" class="text-xs"></div>
        <div data-role="gpu" class="text-xs text-stone-500"></div>
      </section>
      <div data-role="map" class="h-[70vh] border border-sage-300"></div>`;
    const q = (r) => this.el.querySelector(`[data-role=${r}]`);
    this.ui = { dot: q("dot"), state: q("state"), toggle: q("toggle"), job: q("job"), step: q("step"), thumb: q("thumb"), marks: q("marks"), mine: q("mine"), gpu: q("gpu") };
    this.workerId = crypto.randomUUID();
    this.done = 0; this.paused = false; this.busy = false;
    this.ui.toggle.onclick = () => { this.paused = !this.paused; this.ui.toggle.textContent = this.paused ? "Resume" : "Pause"; if (!this.paused) this.next(); else this.setState("Paused after this sheet", "bg-amber-500"); };

    this.map = L.map(this.el.querySelector("[data-role=map]"), { zoomSnap: 0.25 }).setView([40.2, -74.6], 8);
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", { maxZoom: 19, attribution: "© OpenStreetMap contributors" }).addTo(this.map);
    this.layers = L.layerGroup().addTo(this.map);
    this.current = L.layerGroup().addTo(this.map); // the sheet this browser is working on
    this.pushEvent("recent", {}, ({ items }) => { items.slice().reverse().forEach((it) => this.show(it, false)); this.fitAll(); });
    this.handleEvent("result", (it) => this.show(it, true));
    this.handleEvent("wake", () => { if (!this.busy && !this.paused) this.next(); });

    if (!navigator.gpu) {
      this.setState("This browser can't help yet: it has no WebGPU (try a recent Chrome or Edge).", "bg-red-600");
      return;
    }
    this.lost = 0; // GPU losses in a row
    // WebGPU without an adapter (blocklisted driver, headless browser): take no sheets, or every
    // one claimed fails at once and uses up its tries
    navigator.gpu.requestAdapter().then((a) => {
      if (!a) return this.setState("This browser can't help yet: WebGPU found no usable GPU.", "bg-red-600");
      this.startWorker();
      this.next();
    });
  },

  // a fresh worker means a fresh GPU device and fresh OCR sessions
  startWorker() {
    if (this.worker) this.worker.terminate();
    this.worker = new Worker(this.el.dataset.worker, { type: "module" });
    this.worker.onmessage = (e) => this.onWorker(e.data);
    this.worker.onerror = (e) => this.finish({ error: `worker: ${e.message}` });
  },

  destroyed() {
    if (this.worker) this.worker.terminate();
    clearTimeout(this.timer);
  },

  setState(text, dot) {
    this.ui.state.textContent = text;
    this.ui.dot.className = `inline-block w-3 h-3 rounded-full ${dot}`;
  },

  // pushEvent whose reply may never come (the LiveView restarted): give up after `ms`
  ask(event, payload, ms, cb) {
    let answered = false;
    const t = setTimeout(() => { if (!answered) { answered = true; cb(null); } }, ms);
    this.pushEvent(event, payload, (reply) => { if (!answered) { answered = true; clearTimeout(t); cb(reply); } });
  },

  next() {
    clearTimeout(this.timer);
    if (this.busy || this.paused || !this.worker) return;
    this.busy = true;
    this.ask("claim", { worker: this.workerId }, 20000, (reply) => {
      const job = reply && reply.job;
      if (!job) {
        this.busy = false;
        this.setState("Waiting for sheets to be queued", "bg-stone-400");
        this.ui.job.textContent = ""; this.ui.step.textContent = ""; this.ui.thumb.classList.add("hidden");
        this.timer = setTimeout(() => this.next(), WAIT_EMPTY_MS);
        return;
      }
      this.job = job; this.started = performance.now();
      this.setState("Working", "bg-emerald-600");
      this.ui.job.innerHTML = `<b>${job.canvas.label}</b> · ${job.atlas.label}`;
      this.ui.thumb.src = `${job.canvas.service}/full/!600,600/0/default.jpg`;
      this.marks(null);
      this.ui.thumb.classList.remove("hidden");
      this.follow(job);
      this.worker.postMessage({ id: job.id, job });
    });
  },

  onWorker(m) {
    if (!this.job || m.id !== this.job.id) return;
    if (m.type === "step") {
      this.ui.step.textContent = `${m.step} (${Math.round((performance.now() - this.started) / 1000)} s)`;
      if (m.data && (m.data.parts || m.data.labels)) this.marks(m.data);
      if (m.data && m.data.fit) this.showFit(m.data.fit);
    } else if (m.type === "done") {
      this.finish({ result: m.result });
    } else if (m.type === "error") {
      this.finish({ error: m.error });
    }
  },

  // the sheet's parts and the street names read so far, drawn over the thumbnail
  marks(data) {
    const cv = this.ui.marks, img = this.ui.thumb, ctx = cv.getContext("2d");
    const W = (cv.width = img.clientWidth || 1), H = (cv.height = img.clientHeight || 1);
    ctx.clearRect(0, 0, W, H);
    if (!data || !this.job) return;
    const k = W / this.job.canvas.width;
    ctx.lineWidth = 2; ctx.strokeStyle = "#a0562c";
    for (const p of data.parts || []) {
      ctx.beginPath(); p.forEach(([x, y], i) => (i ? ctx.lineTo(x * k, y * k) : ctx.moveTo(x * k, y * k))); ctx.closePath(); ctx.stroke();
    }
    ctx.font = "10px sans-serif";
    for (const l of data.labels || []) {
      const x = l.px[0] * k, y = l.px[1] * k;
      ctx.fillStyle = "#15803d"; ctx.beginPath(); ctx.arc(x, y, 3, 0, 7); ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,.8)"; ctx.fillRect(x + 4, y - 9, ctx.measureText(l.name).width + 4, 12);
      ctx.fillStyle = "#14532d"; ctx.fillText(l.name, x + 6, y);
    }
  },

  finish({ result, error }) {
    const job = this.job;
    this.job = null;
    const after = () => { this.busy = false; this.next(); };
    if (!job) return after();
    if (result) {
      this.lost = 0;
      if (result.gpu) this.ui.gpu.textContent = `GPU: ${[result.gpu.vendor, result.gpu.architecture].filter(Boolean).join(" ")}`;
      this.ask("complete", { job_id: job.id, worker: this.workerId, result }, 60000, (reply) => {
        if (reply && reply.ok) this.current.clearLayers(); // the saved result arrives on the feed
        if (!reply || !reply.ok) this.ui.step.textContent = `Couldn't save that sheet${reply ? `: ${reply.error}` : ""}`;
        this.done++;
        const ok = result.parts.filter((p) => p.status === "ok").length;
        this.ui.mine.textContent = `This session: ${this.done} sheet${this.done === 1 ? "" : "s"} (last: ${ok} of ${result.parts.length} parts placed, ${Math.round((performance.now() - this.started) / 1000)} s)`;
        after();
      });
    } else if (/device (is )?lost|\[Device\][^\n]*lost/i.test(String(error))) {
      // the GPU went away (the machine slept, a driver reset): hand the sheet back untouched and
      // start over with a new device; give up for now after three losses in a row
      this.lost++;
      this.ui.step.textContent = "Lost the GPU (did the computer sleep?); starting again";
      this.ask("release", { worker: this.workerId }, 20000, () => {
        this.startWorker();
        if (this.lost >= 3) {
          this.paused = true; this.busy = false;
          this.ui.toggle.textContent = "Resume";
          this.setState("Paused: the GPU keeps getting lost. Resume to try again.", "bg-red-600");
          this.lost = 0;
        } else setTimeout(after, 5000);
      });
    } else {
      this.ui.step.textContent = `Failed: ${String(error).split("\n")[0]}`;
      this.ask("fail", { job_id: job.id, worker: this.workerId, error: String(error) }, 20000, after);
    }
  },

  show(it, live) {
    for (const p of it.parts) {
      const ok = p.status === "ok";
      // a key map (the atlas overview) would bury the sheets: outline only
      if (ok && !p.key_map) this.layers.addLayer(new SheetOverlay(it, p));
      const poly = L.polygon(p.outline.map(([lon, lat]) => [lat, lon]), {
        color: ok ? "#15803d" : "#d97706", weight: ok ? 1.5 : 1, fill: !ok, fillOpacity: 0.08, dashArray: ok ? null : "4 3",
      }).bindTooltip(`${it.canvas} · ${it.atlas}${ok ? "" : " (unsure)"}`);
      this.layers.addLayer(poly);
    }
  },

  // a sheet just claimed: show its town while the sheet is read
  follow(job) {
    this.current.clearLayers();
    const b = job.bbox;
    if (!b) return;
    const town = L.rectangle([[b[1], b[0]], [b[3], b[2]]], { color: "#a0562c", weight: 1, dashArray: "6 4", fill: false, interactive: false });
    this.current.addLayer(town);
    this.map.flyToBounds(town.getBounds(), { duration: 1.2, maxZoom: 15 });
  },

  // a part of the sheet this browser is working on was just fitted: go there
  showFit(fit) {
    const pr = this.job && this.job.projection;
    if (!pr || !fit.transform) return;
    const T = fromAB(fit.transform);
    const ll = fit.mask.map(([u, v]) => { const [x, y] = fwd(T, u, v); return [pr.lat0 + y / pr.ky, pr.lon0 + x / pr.kx]; });
    const ok = fit.status === "ok";
    const poly = L.polygon(ll, { color: ok ? "#a0562c" : "#d97706", weight: 3, dashArray: ok ? null : "6 4", fillOpacity: 0.1 })
      .bindTooltip(`${this.job.canvas.label}, part ${fit.part}${ok ? "" : " (unsure)"}: being checked by your computer`);
    this.current.addLayer(poly);
    this.map.flyToBounds(poly.getBounds().pad(fit.key_map ? 0.1 : 1), { duration: 1.2, maxZoom: 17 });
  },

  fitAll() {
    const b = L.latLngBounds([]);
    this.layers.eachLayer((l) => l.getBounds && b.extend(l.getBounds()));
    if (b.isValid()) this.map.fitBounds(b.pad(0.1));
  },
};
