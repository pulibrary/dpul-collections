import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
import Loader from './loader';
// DpulcViewer is a react component which acts as a wrapper for Clover with
// all of our default settings and functionality.
const handleCanvasIdCallback = (activeCanvasId, pushEvent) => {
  // Tell LiveView that we've changed the canvas so we can change the URL or
  // anything else, if necessary.
  if(typeof pushEvent === 'function') {
    pushEvent("changedCanvas", { "canvas_id": activeCanvasId })
  }
};
export default function DpulcViewer(props) {
  return (
    <>
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
    </>
  );
}
