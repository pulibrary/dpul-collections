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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// loading transitions
window.addEventListener("phx:page-loading-start", info => {
  if (info.detail.kind == "redirect") {
    const main = document.querySelector("main");
    main.classList.add("phx-page-loading")
  }
})

window.addEventListener("phx:page-loading-stop", info => {
  const main = document.querySelector("main");
  main.classList.remove("phx-page-loading")
})

// window.addEventListener("phx:navigate", info => {
//   const items = document.querySelectorAll(".item");
//   // console.log(items)
//   // main.classList.add("phx-page-loading")
//   items.forEach(function (currentValue, currentIndex, listObj) {
//     currentValue.classList.add("fade-transition"); // Set initial hidden state

//     // Wait for the next animation frame, then add the active class to start the transition
//     requestAnimationFrame(() => {
//       currentValue.classList.add("fade-transition-active");
//     });

//     // Clean up classes after the transition completes
//     currentValue.addEventListener("transitionend", () => {
//       currentValue.classList.remove("fade-transition", "fade-transition-active");
//     }, { once: false });

//     console.log(`${currentValue}, ${currentIndex}, ${this}`);
//   }, "myThisArg");
// })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

