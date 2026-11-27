// Background georeferencing worker: runs the whole per-canvas pipeline off the page's main thread.
// Messages in: {id, job}. Out: {id, type: "step", step} ..., then {id, type: "done", result}
// or {id, type: "error", error}.
import { processCanvas } from "./pipeline";

self.onmessage = async (e) => {
  const { id, job } = e.data;
  try {
    const result = await processCanvas(job, (step, data) => self.postMessage({ id, type: "step", step, data }));
    self.postMessage({ id, type: "done", result });
  } catch (err) {
    self.postMessage({ id, type: "error", error: String((err && err.stack) || err) });
  }
};
