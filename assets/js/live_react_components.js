// Load Clover in its own file, so it only downloads for the viewer route.
import LiveReact, { initLiveReact } from "phoenix_live_react"
import DpulcViewer from "./dpulc_viewer"

window.Components = {
  DpulcViewer
}

export { LiveReact, initLiveReact }
