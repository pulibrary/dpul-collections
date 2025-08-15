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
    "grid-template-columns": "1fr min-content"
  },
  ".clover-viewer-media-wrapper > div[role='radiogroup']": {
    "flex-direction": "column"
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
