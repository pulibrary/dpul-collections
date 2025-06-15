import Viewer from "@samvera/clover-iiif/viewer";
import React from 'react';
export default function DpulcViewer(props) {
  const output =  (
    <>
    < Viewer {...props} />
    </>
  );
  window.output = output;
  return output;
}
