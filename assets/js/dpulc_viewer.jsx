import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
import Loader from './loader';
import { createStitches } from '@stitches/react';
import DownloadButton from "./download_button"
const { styled } = createStitches({
  media: {
    sm: '(min-width: 640px)',
    md: '(min-width: 768px)',
    lg: '(min-width: 1024px)',
    xl: '(min-width: 1280px)'
  },
});
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

const StyledViewer = styled("section", {
  ".clover-viewer-header": {
    "display": "none"
  },
  ".clover-viewer-media-wrapper": {
    "padding-top": "10px"
  },
  "@sm": {
    ".clover-viewer-content > div": {
      "display": "grid",
      "grid-template-columns": "min-content 1fr",
      "gap": "1rem"
    },
    ".clover-viewer-media-wrapper > div[role='radiogroup']": {
      "flex-direction": "column",
      "height": 0,
      "overflow-x": "hidden",
      "overflow-y": "scroll"
    },
    ".clover-viewer-painting": {
      "grid-column-start": 2,
      "grid-row-start": 1,
    },
    ".clover-viewer-media-wrapper": {
      "grid-column-start": 1,
      "grid-row-start": 1,
      "display": "flex",
      "flex-direction": "column",
      "gap": "1rem",
      "align-items": "center"
    },
    ".clover-viewer-media-wrapper > div:first-child > div": {
      "position": "unset"
    },
    ".clover-viewer-media-wrapper > div:first-child": {
      "width": "unset",
      "position": "unset"
    }
  }
})

const downloadPlugin = {
  id: "download-button",
  imageViewer: {
    controls: {
      component: DownloadButton,
    },
  },
};

export default function DpulcViewer(props) {
  return (
    <>
    <StyledViewer>
    <Viewer
      canvasIdCallback={(activeCanvasId) => { handleCanvasIdCallback(activeCanvasId, props.contentCanvasIndex, props.pushEvent) }}
      plugins={[downloadPlugin]}
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
    </StyledViewer>
    </>
  );
}
