import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
// DpulcViewer is a react component which acts as a wrapper for Clover with
// all of our default settings and functionality.
export default function DpulcViewer(props) {
  return (
    <>
    <Viewer
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
