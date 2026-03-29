import Mirador from "mirador";
import miradorDownloadPlugins from "mirador-dl-plugin";

const MiradorViewer = {
  mounted() {
    this.initMirador();
  },

  initMirador() {
    const manifestUrl = this.el.dataset.manifestUrl;
    const canvasId = this.el.dataset.canvasId;

    // Clear any previous instance
    this.el.innerHTML = "";

    // Create a container div for Mirador to render into
    const container = document.createElement("div");
    container.id = "mirador-viewer";
    container.style.width = "100%";
    container.style.height = "100%";
    container.style.position = "absolute";
    this.el.appendChild(container);

    const windowConfig = {
      manifestId: manifestUrl,
    };

    if (canvasId) {
      windowConfig.canvasId = canvasId;
    }

    const viewerInstance = Mirador.viewer(
      {
        id: "mirador-viewer",
        windows: [windowConfig],
        workspaceControlPanel: { enabled: false },
        window: {
          allowClose: false,
          allowMaximize: false,
          allowFullscreen: true,
          allowWindowSideBar: true,
          allowTopMenuButton: true,
          hideWindowTitle: false,
          sideBarOpen: false,
          defaultView: "single",
          panels: {
            info: false,
            attribution: false,
            canvas: true,
            annotations: true,
            search: true,
            layers: true,
          },
        },
        thumbnailNavigation: {
          // Very annoying, but gotta move this setting around.
          defaultPosition: "far-right",
          displaySettings: false,
        },
        workspace: {
          showZoomControls: true,
        },
        osdConfig: {
          gestureSettingsMouse: {
            scrollToZoom: false,
          },
        },
      },
      [...miradorDownloadPlugins]
    );

    this.viewerInstance = viewerInstance;
    const { store } = viewerInstance;

    const mobileQuery = window.matchMedia("(max-width: 639px)");
    const updateThumbnailPosition = (mobile) => {
      const state = store.getState();
      const windowIds = Object.keys(state.windows);
      if (windowIds.length === 0) return;
      const wId = windowIds[0];
      store.dispatch({
        type: "mirador/UPDATE_COMPANION_WINDOW",
        windowId: wId,
        id: state.windows[wId].thumbnailNavigationId,
        payload: { position: mobile ? "far-bottom" : "far-right" },
      });
    };
    /* Update the placement of the mobile thumbnails based on screen size. */
    /* Wait for the store to send an event with windows, when it gets it call
     * the unsubscribe function that store.subscribe() returns */
    const unsubInit = store.subscribe(() => {
      const state = store.getState();
      const windowIds = Object.keys(state.windows);
      if (windowIds.length > 0 && state.windows[windowIds[0]].thumbnailNavigationId) {
        unsubInit();
        updateThumbnailPosition(mobileQuery.matches);
      }
    });
    mobileQuery.addEventListener("change", (e) => updateThumbnailPosition(e.matches));

    // Notify LiveView that the canvas changed when the store updates with a new
    // canvas ID.
    let previousCanvasId = canvasId;

    store.subscribe(() => {
      const state = store.getState();
      const windows = state.windows;
      const windowIds = Object.keys(windows);

      if (windowIds.length === 0) return;

      const windowState = windows[windowIds[0]];
      if (!windowState) return;

      const currentCanvasId = windowState.canvasId;
      if (currentCanvasId && currentCanvasId !== previousCanvasId) {
        previousCanvasId = currentCanvasId;
        this.pushEvent("changedCanvas", { canvas_id: currentCanvasId });
      }
    });
  },
};

export default MiradorViewer;
