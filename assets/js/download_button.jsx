import React, { useState } from "react";
import { makeBlob, mimicDownload } from "@samvera/image-downloader";
import * as Popover from "@radix-ui/react-popover";
import Download from "./download_icon";

const DEFAULT_SCALE = "1000,0";
const DOWNLOAD_OPTIONS = {
  small: {
    label: "Small JPG",
    scale: "1200,",
  },
  fullsize: {
    label: "Full-sized JPG",
    scale: "max",
  },
};

export default function DownloadButton({ useViewerState }) {
  const viewerState = useViewerState();
  const { activeCanvas, vault } = viewerState;
  const canvasData = vault.toPresentation3({
    id: activeCanvas,
    type: "Canvas",
  });
  const [open, setOpen] = useState(false);

  // Same URL generation logic as above
  const generateAssetUrls = () => {
    // Looks like our manifest has a bug.
    const iiifAssetPath = canvasData.items[0].items[0].body.service[0]['@id']
    const originalRendering = canvasData.rendering.find(elem => elem.format == "image/tiff")

    return {
      small: `${iiifAssetPath}/full/${DOWNLOAD_OPTIONS.small.scale}/0/default.jpg`,
      fullsize: `${iiifAssetPath}/full/${DOWNLOAD_OPTIONS.fullsize.scale}/0/default.jpg`,
      original: {
        label: originalRendering.label,
        path: originalRendering.id,
      },
    };
  };

  // this can be removed (maybe when we upgrade to React 19 with built in memoization)
  const assetUrls = generateAssetUrls();

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger asChild>
        <button
          type="button"
          className="hover:bg-clover-accent cursor-pointer rounded-full bg-black ml-[10px] w-[32px] flex items-center justify-center"
          aria-label="Download image"
        >
          <Download />
        </button>
      </Popover.Trigger>

      <Popover.Portal>
        <Popover.Content
          className="z-3 bg-white border rounded shadow-lg p-3"
          align="end"
          sideOffset={5}
        >
          <h2 className="px-2 mb-3">Download image</h2>
          <ul className="list-unstyled list-group">
            {Object.entries(DOWNLOAD_OPTIONS).map(([key, option]) => (
              <li key={key}>
                <a
                  href={assetUrls[key]}
                  type="button"
                  className="cursor-pointer hover:link-hover"
                  target="_blank"
                >
                  {option.label}
                </a>
              </li>
            ))}
            <li>
              <a
                href={assetUrls.original.path}
                target="_blank"
                className="cursor-pointer hover:link-hover"
              >
                {assetUrls.original.label.en || assetUrls.original.label.none}
              </a>
            </li>
          </ul>
        </Popover.Content>
      </Popover.Portal>
    </Popover.Root>
  );
}
