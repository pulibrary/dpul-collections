<script>
import { TriiiceratopsViewer } from 'triiiceratops';
import { ImageDownloadPlugin } from 'triiiceratops/plugins/image-download';
import 'triiiceratops/style.css';
import '../css/triiiceratops-themes.css';
let viewerState = $state();
let {manifestId, initialId, live, ...allProps} = $props()
let canvasId = $state(initialId)
let config =
{
  "showToggle": true,
  "toolbarOpen": true,
  "showCanvasNav": true,
  "showZoomControls": true,
  "enableDragDrop": true,
  "leftPanelWidth": "320px",
  "rightPanelWidth": "320px",
  "toolbar": {
    "showSearch": true,
    "showGallery": true,
    "showAnnotations": false,
    "showFullscreen": true,
    "showInfo": false,
    "showViewingMode": true,
    "side": "left",
    "anchor": "center",
    "showStructures": true,
    "showCollection": true
  },
  "gallery": {
    "open": true,
    "draggable": true,
    "showCloseButton": true,
    "dockPosition": "bottom"
  },
  "search": {
    "open": false,
    "showCloseButton": true,
    "query": ""
  },
  "annotations": {
    "open": false,
    "showCloseButton": true
  },
  "information": {
    "open": false,
    "showCloseButton": true,
    "position": "right",
    "showButton": true
  },
  "structures": {
    "open": false,
    "showCloseButton": true
  },
  "collection": {
    "open": false,
    "showCloseButton": true
  },
  "controls": "split",
  "nav": {
    "style": "docked",
    "edge": "bottom",
    "align": "start"
  },
  "transparentBackground": false,
  "preserveCanvasScale": true,
  "pagedViewOffset": true
}

$effect(() => {
  if (viewerState?.canvasId && viewerState.canvasId !== canvasId) {
    canvasId = viewerState.canvasId;
    live.pushEvent("changedCanvas", { "canvas_id": canvasId })
  }
})
</script>

<div class="triiiceratops-styles absolute w-full h-full">
  <TriiiceratopsViewer theme="light" bind:viewerState plugins={[ImageDownloadPlugin]} {canvasId} {manifestId} {config} />
</div>
