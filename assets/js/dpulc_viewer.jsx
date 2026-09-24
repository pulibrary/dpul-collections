import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
import Loader from './loader';
// DpulcViewer is a react component which acts as a wrapper for Clover with
// all of our default settings and functionality.
let currentCanvas = null
const handleCanvasIdCallback = (activeCanvasId, loadedCanvasIdx, pushEvent) => {
  // In vertical thumbnails, scroll to view.
  scrollThumbnail(activeCanvasId, loadedCanvasIdx - 1)
  // Tell LiveView that we've changed the canvas so we can change the URL or
  // anything else, if necessary.
  if(typeof pushEvent === 'function') {
    pushEvent("changedCanvas", { "canvas_id": activeCanvasId })
  }
};

// Clover scrolls the thumbnail bar horizontally already in https://github.com/samvera-labs/clover-iiif/blob/03d6a9292a4d60ff2b6524a5579af34ad30dc3b2/src/components/Viewer/Media/Media.tsx#L76-L81, but we need to handle vertical scroll.
const scrollThumbnail = (activeCanvasId, loadedCanvasIdx) => {
  const canvasThumbnail = document.querySelector(`button[value='${activeCanvasId}']`)
  if(canvasThumbnail) {
    const allThumbnails = document.querySelectorAll(`div[role='radiogroup'] button`)
    const canvasContainer = canvasThumbnail.closest("div[role='radiogroup']")
    const thumbnailRect = canvasThumbnail.getBoundingClientRect()
    const containerRect = canvasContainer.getBoundingClientRect()

    const isOutsideVertically = thumbnailRect.top < containerRect.top || thumbnailRect.bottom > containerRect.bottom;
    if (currentCanvas != canvasThumbnail && isOutsideVertically) {
      // If we're loading the first canvas we were asked to load, then scroll
      // the bar so it's at the top.
      const isStartup = Array.prototype.indexOf.call(allThumbnails, canvasThumbnail) == loadedCanvasIdx
      if(isStartup) {
        canvasThumbnail.scrollIntoView();
      // Otherwise scroll it as close as we can - used for the left/right
      // buttons.
      } else {
        canvasThumbnail.scrollIntoView({ block: 'nearest' });
      }
      currentCanvas = activeCanvasId
    }
  }
}

export default function DpulcViewer(props) {
  return (
    <>
    <section className="dpulc-viewer">
    <Viewer
    canvasIdCallback={(activeCanvasId) => { handleCanvasIdCallback(activeCanvasId, props.contentCanvasIndex, props.pushEvent) }}
      options={
        {
          canvasHeight: "auto",
          customLoadingComponent: () => <Loader />,
          openSeadragon: {
            mouseNavEnabled: true,
            gestureSettingsMouse: {
              clickToZoom: true,
              scrollToZoom: true
            }
          },
            informationPanel: {
              open: false,
                renderAbout: false,
                renderToggle: false,
                renderAnnotation: false
            }
        }
      }
      {...props}
    />
    </section>
    </>
  );
}
