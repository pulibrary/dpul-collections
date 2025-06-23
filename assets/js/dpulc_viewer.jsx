import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
// DpulcViewer is a react component which acts as a wrapper for Clover with
// all of our default settings and functionality.
const handleCanvasIdCallback = (activeCanvasId, pushEvent) => {
  pushEvent("changedCanvas", activeCanvasId)
};
export default function DpulcViewer(props) {
  return (
    <>
    <Viewer
    canvasIdCallback={(activeCanvasId) => { handleCanvasIdCallback(activeCanvasId, props.pushEvent) }}
      options={
        {
          canvasHeight: "auto",
          openSeadragon: {
            mouseNavEnabled: false,
              gestureSettings: {
                scrollToZoom: false
              }
          },
            informationPanel: {
              open: false,
                renderAbout: false,
                renderToggle: false
            }
        }
      }
      {...props}
    />
    </>
  );
}
