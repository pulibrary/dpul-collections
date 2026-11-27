# Collaborative georeferencing of Sanborn atlases (prototype)

Volunteers' browsers georeference Sanborn fire insurance maps: while a
volunteer has the page open, their computer takes sheets from a queue, reads
them, and fits each part of a sheet to the town's modern OpenStreetMap streets
on their GPU. The server only prepares atlases, hands out work and keeps the
results. Parts the browsers aren't sure of are placed by people on a separate
page. Results are IIIF Georeference Annotations (viewable in Allmaps).

## Where it lives, switching it off, removing it

Everything is in its own folders; outside them only a few lines refer to it.

| | |
|---|---|
| server | `lib/dpul_collections/georef.ex`, `lib/dpul_collections/georef/` |
| web (pages, controller, routes) | `lib/dpul_collections_web/georeferencer/` (`DpulCollectionsWeb.Georeferencer.*`) |
| browser | `assets/js/georeferencer/` (page hooks, Web Worker, OCR, fitting) |
| tests | `test/dpul_collections/georef/`, `test/dpul_collections_web/georeferencer/`, `test/support/georef/` (fixtures, a stand-in for `osmium`) |
| outside those | `use DpulCollectionsWeb.Georeferencer.Routes` in the router; two lines in `assets/js/hooks.js`; the `js/georeferencer/worker.js` entry and the fs/path/crypto externals in the esbuild args (`config/config.exs`); the `:georeferencer` and `DpulCollections.Georef` settings in `config/dev.exs` and `config/test.exs`; npm packages `onnxruntime-web`, `@techstark/opencv-js`, `leaflet`; migrations `2026112616*`–`2026112618*` (tables `georef_atlases`, `georef_jobs`, `georef_contributions`) |

**On and off**: `config :dpul_collections, :georeferencer, enabled: true` (on in
dev and test, off by default, so off in production). Off, every
`/georeferencer` request is a 404 (`Georeferencer.Routes`, a plug plus a
LiveView `on_mount` check); it is read at runtime, so no rebuild is needed.

**Removing it**: delete the folders above, then the lines listed under
"outside those", then `npm uninstall onnxruntime-web @techstark/opencv-js
leaflet` in `assets/`, and add a migration dropping `georef_contributions`,
`georef_jobs` and `georef_atlases` (in that order). Cached images, OSM extracts
and OCR models are in `~/.cache/dpul_georef` (`Georef.cache_dir/0`).

## Pages

* `/georeferencer` — the main page. Shows the queue (atlases in order, with
  progress), a form to add an atlas by IIIF manifest URL, the worker's status
  and a live map. There is no choosing what to run: every open page takes the
  oldest waiting sheet. The map follows the sheet being worked on (its town on
  claim, each part as it is fitted, using the atlas projection sent with the
  job) and shows everyone's finished sheets, warped into place.
* `/georeferencer/review` — placing by hand, opened in a new tab from the main
  page (see below).
* `/georeferencer/results` — your contributions (JSON, Allmaps links) and each
  atlas's AnnotationPage (`/georeferencer/atlas/:id/georef.json`); an atlas
  opens in the editor (`/georeferencer/:atlas/:index`) to check or adjust fits.

## Server (`DpulCollections.Georef.Collab*`, cheap work only)

* `Queue.enqueue(manifest_url)`: fetches the manifest (`Georef.Manifest`),
  finds the town (`Georef.search_bbox`: the title's place in OSM, the catalog
  bbox only as a hint) and prepares its OSM extract (`Georef.Osm`, from a
  state `.osm.pbf` clipped with `osmium`; nothing is fetched at query time).
  Each canvas becomes a `georef_jobs` row.
* Claims are `FOR UPDATE SKIP LOCKED`, oldest first. A closed tab's claim goes
  straight back (the LiveView's `terminate` calls `Queue.release`); any other
  claim quiet for 10 minutes is handed out again; after three failures a job
  is `failed`. Quiet claims count as waiting in the queue's numbers.
* A finished job stores the browser's result; each placed part becomes a
  `georef_contributions` row credited to the signed-in user, with its IIIF
  Georeference Annotation (`creator: urn:dpul:user:ID`).
* Atlas-wide steps run over all the browsers' results: renames (below) and
  `Georef.Consistency` (same-scale parts overlapping by more than half on the
  ground are both declined, unless a key map vouches for one; sheet numbers on
  key maps come from the whole-sheet words the browser sends back).
* The server also serves what the browser can't fetch itself: same-origin
  sheet images at fixed IIIF sizes (cached in `~/.cache/dpul_georef/img`), the
  OCR models (`~/.cache/dpul_georef/ocr_web`) and the town's streets
  (`/georeferencer/atlas/:id/osm.json`).

**Renames.** For each part it placed, the browser reports which modern street
each street-name sized word sits on (`pipeline.js` `observeRenames`). When an
atlas's first round is done, `Renames.table` turns agreeing votes (>= 2,
>= 75 %) into aliases ("MAIN" in Swedesboro is now Kings Highway), and the
canvases with an unplaced part are queued again (round 2) with them. A round-2
result replaces round 1 only when it places more parts.

## Browser (`assets/js/georeferencer/`, in a Web Worker: `worker.js`)

Per canvas (`pipeline.js` `processCanvas`), about 30 s on an M2 Max, 21 s of
it OCR; OCR results are cached in IndexedDB:

1. **Border and parts** (`sheetgeom.js`, OpenCV.js 4.10): the neatline on a
   1536 px overview, then parts split along Sanborn's heavy rules (areas that
   are not continuous) on a 2000 px image.
2. **OCR** (`ocr.js`): RapidOCR's PP-OCRv6 small detection + recognition and
   the v2 angle classifier, run by onnxruntime-web on WebGPU; the whole sheet
   at 3000 px plus 30 overlapping tiles, each read upright and turned 90° for
   vertical names.
3. **Street names** (`labels.js`): words matched to the town's modern street
   names (normalised: suffixes, directions, ordinals; Jaro >= 0.93),
   letter-spaced names joined ("B … ST."), library stamps and the title's town
   name dropped, the printed scale read.
4. **Fit, per part** (`search.js`, `gpu.js`, `engine.js`):
   * a GPU search puts every pair of far-apart names on every pair of points
     of their two streets (5 m apart; 1–20 M placements in 10–20 ms), scored
     by how many names then land on their own streets; plus placements implied
     by named crossings;
   * near-best placements (one per 20 m / 3° / 2 % cell) are snapped (names
     least squares, matching radius 20 → 12 → 8 m, never losing a name), ranked
     by names on streets + 3 × corridor contrast, and the best three refined in
     the printed street corridors;
   * **corridor contrast**: how much more of the modern street centreline falls
     in the sheet's printed street corridors (white bands between building ink)
     here than at nearby placements. A true fit is a peak; a ladder of parallel
     names landing on the wrong parallel streets is not.
5. **Acceptance**: enough names (max(3, 25 % of those read)), on streets
   crossing each other, at a scale consistent with the printed one (355–427
   dpi; key maps under a sheet's scale statement are searched at their own
   scale), and printed streets that line up (corridor contrast >= 0.1; key
   maps excepted, their streets are drawn too small). A lead in names never
   stands in for the corridors: Como 1907 Sheet 17 had 8 of 10 names on their
   streets at a 45° wrong angle, because five of them sat in one row across
   parallel avenues (contrast 0.055). A fit failing only this test is kept as
   "unsure" for a person. The server applies the same check to every result
   it receives (`Queue.checked`), so a browser's "ok" is not taken on trust,
   and an automatic contribution stops counting if its part fails it.

## Placing by hand (`/georeferencer/review`, `Collab.Review`)

Parts the browsers didn't place confidently (unsure, colliding with another
sheet, or unplaced), minus those a person already decided (`Collab.human?`),
easiest first:

1. a guess whose printed streets line up with the modern ones (corridor
   contrast >= 0.1, `Review.lines_up?`), ordered by contrast, then names and
   their lead over the next-best spot. Every confident fit so far scored
   >= 0.13 and the wrong guesses seen < 0.05, while name counts alone could not
   tell them apart (a wrong guess put 6 of 7 names on streets);
2. guesses colliding with another sheet;
3. parts with names but no believable guess (a guess that doesn't line up is
   flagged in the editor as probably wrong);
4. parts with little to go on (one name or none; often not a map).

The editor draws OpenStreetMap tiles under the sheet, names along the modern
street lines, and opens on the computer's guess. Picking a street name
highlights its modern street; clicking on it pins the name there. One pin
moves the sheet, two solve scale and rotation too (then a snap pulls the other
names on if it keeps as many). Arrow keys nudge, `<` `>` turn, `-` `+` resize,
holding Space shows the map through the sheet. Saving moves on to the next
part and puts the placement on everyone's map.

## Design notes (measured on the earlier server prototype)

* Identity comes from printed street names and geometry, not from a vision
  language model: VLM point grounding was precise (2–7 m) but its identity
  unreliable, and a VLM asked whether a fit was aligned said yes to fits
  shifted 100 m. Image processing beat VLM steps throughout.
* Checks must be able to fail. Names on streets alone can be fooled by
  parallel streets; the corridor contrast separates them.
* Corridors are a ranking signal, not an optimiser: modern centrelines are not
  the historic corridors, and pixel-wise corridor alignment moved good fits a
  few metres off.
* On 61 parts of Palmyra, Moorestown and Red Bank, the browser placed 44 to the
  server prototype's 48 (42 by both, 37 of those within 20 m of each other);
  the misses had 2–5 readable names, which is what hand placement is for.

## Gotchas

* OpenCV.js's module object is a thenable that resolves to itself: never
  return it from an async function or resolve a promise with it. Its heap
  grows as Mats are made, detaching earlier `.data` views (copy them).
* LiveView copies a hook object's callbacks onto the hook instance (don't
  `Object.assign` the instance into another object).
* Phoenix's CSRF plug refuses JavaScript responses on `:browser` routes; the
  ONNX runtime's module is served outside that pipeline.
* Headless Chromium needs `--use-angle=metal` for a real GPU adapter.
* Live reload during development restarts the volunteer page; its claim is
  released, but each restart is a new worker.

## Known limits / next steps

* Results are trusted as sent; the server should re-score submitted fits
  (cheap: the corridor score of one transform).
* Several routes serve files only a dev checkout has (the OCR models from the
  local cache, the ONNX runtime from `node_modules`); production needs them
  as static assets. OSM tiles come from tile.openstreetmap.org, fine for a
  prototype only.
* Two people can place the same part at once; the later save wins.
