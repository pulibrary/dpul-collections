import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
import Loader from './loader';
import { styled } from '@stitches/react';
// DpulcViewer is a react component which acts as a wrapper for Clover with
// all of our default settings and functionality.
const handleCanvasIdCallback = (activeCanvasId, pushEvent) => {
  // Tell LiveView that we've changed the canvas so we can change the URL or
  // anything else, if necessary.
  if(typeof pushEvent === 'function') {
    pushEvent("changedCanvas", { "canvas_id": activeCanvasId })
  }
};

const StyledViewer = styled("section", {
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
    "gap": "1rem"
  },
  ".clover-viewer-media-wrapper > div:first-child > div": {
    "position": "unset",
  }
})
export default function DpulcViewer(props) {
  return (
    <>
    <StyledViewer>
    <Viewer
    canvasIdCallback={(activeCanvasId) => { handleCanvasIdCallback(activeCanvasId, props.pushEvent) }}
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
