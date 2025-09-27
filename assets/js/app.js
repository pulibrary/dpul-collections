// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Hooks from "./hooks";
import {hooks as colocatedHooks} from "phoenix-colocated/dpul_collections"
import { initLiveReact } from "phoenix_live_react"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  // Use long polling only in production
  longPollFallbackMs: window.location.host.startsWith("localhost") ? undefined : 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
window.addEventListener("dpulc:scrollTop", () => {window.scrollTo(0,0)})
window.addEventListener("dpulc:scrollTo", (event) => {event.target.scrollIntoView()})

// Event to change locale cookie from Language drop down and reload page so
// LiveView components are remounted with new langauge setting.
window.addEventListener("setLocale", e => {
    const maxAge = 365 * 24 * 60 * 60
    document.cookie = `locale=${e.detail.locale}; max-age=${maxAge}; path=/`
    location.reload()
  }
)

window.addEventListener("dpulc:showImages", e => {
    let itemId = e.target.getAttribute("data-id")
    const allImages = document.querySelectorAll('.thumbnail-' + itemId)

    const maxAge = 365 * 24 * 60 * 60
    // update the cookie
    const oldList = document.cookie
        .split("; ")
        .find((row) => row.startsWith("showImages="))
        ?.split("=")[1]
        .split(",")

    let newList = oldList || []
    newList.push(itemId)
    document.cookie = `showImages1=${Array.from(new Set(newList)).join(",")}; max-age=${maxAge}; path=/`

    // show the images
    allImages.forEach(el => {
      el.classList.remove("obfuscate")
    })
  }
)

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Clipboard copy function
window.addEventListener("dpulc:clipcopy", (event) => {
  if ("clipboard" in navigator) {
    const text = event.target.textContent;
    navigator.clipboard.writeText(text);
  }
});

// Initialize react components.
document.addEventListener("DOMContentLoaded", e => {
  initLiveReact()
})

import DpulcViewer from "./dpulc_viewer";

window.Components = {
  DpulcViewer
}
