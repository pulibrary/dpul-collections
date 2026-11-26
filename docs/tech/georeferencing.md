# Automatic georeferencing prototype

Goal: given a IIIF manifest of a scanned map (initially Sanborn fire insurance
sheets from maps.princeton.edu), produce a
[IIIF Georeference](https://iiif.io/api/extension/georef/) AnnotationPage that
opens in [Allmaps](https://viewer.allmaps.org) — using only local compute.

```
mix georef https://maps.princeton.edu/catalog/princeton-t148fm04w
mix georef <manifest-url> --canvases 0,1 --out tmp/georef/paulsboro
GEOREF_MODEL=qwen36_35b mix georef ...              # choose the local VLM
GEOREF_HOST=127.0.0.1 GEOREF_PORT=8092 mix georef ...  # use a llama-server elsewhere
mix georef ... --vlm-labels --vlm-points            # also VLM name reading / junction pointing (off by default)
mix georef ... --no-labels-first                    # ablation: junction fit only
mix georef ... --no-slide                           # ablation: no slide fallback
mix georef ... --no-neighbour                       # ablation: no neighbour placement
```

Writes `<out>.json` (AnnotationPage) and `<out>.report.json` (debug data). In
dev, files under `tmp/georef/` are served with CORS at
`http://localhost:4000/georef/<name>.json` so Allmaps can load them with
`https://viewer.allmaps.org/?url=...`.

## Local components

| What | How | Code |
|---|---|---|
| Vision-language model | `llama-server` (llama.cpp) with Qwen3-VL-8B (default) or Qwen3.6-35B-A3B GGUF; started on demand, or remote via `GEOREF_HOST` | `Georef.Vlm` |
| OCR (text + rotated boxes) | RapidOCR: PP-OCRv5 mobile detection + PP-OCRv6 small recognition (ONNX), `priv/georef/ocr.py` under `uv`; upright + 90°-rotated pass; whole sheet at 3000 px + 2400 px tiles read at 1536 px | `Georef.Ocr` |
| Heavy-rule detection | OpenCV morphology + Hough, `priv/georef/parts.py` under `uv` | `Georef.Parts` |
| Modern streets/rail/water | Geofabrik state `.osm.pbf` clipped with `osmium` (Overpass fallback); junctions via a spatial grid | `Georef.Osm` |
| Geometry | similarity fit, RANSAC, label-to-centreline ICP | `Georef.Geometry` |

Models, OCR results and OSM extracts are cached under `~/.cache/dpul_georef`.

## Pipeline (per canvas)

1. **Where to look.** The catalog bbox is only a hint (Hightstown's points
   at Hamilton, ~15 km away; Camden's covers the county; Bound Brook's clips
   the Middlesex sheets). The title's place name ("Insurance maps of" removed)
   is looked up in OSM places. If it lies inside the padded bbox, the bbox is
   used, but never smaller than a town box (~7 km) and replaced by a town box
   when it is more than twice that size; cities get ~13 km.
2. **Neatline + parts.** The VLM finds the printed border. Heavy rules —
   Sanborn's convention for separating areas that are *not* geographically
   continuous — split the sheet into parts (a rule that steps from one line to
   another is followed through the step). Each part is georeferenced on its own
   with its polygon as the SvgSelector mask. Parts that cannot be fit are left
   out.
3. **Labels.** OCR reads every text line with a rotated box, upright and on a
   90°-rotated copy (north–south street names are printed vertically and were
   otherwise missed). Tokens that fuzzy-match a modern street / railway /
   waterway name become labels with a position and direction; bare street-type
   words ("LANE") never fuzzy-match, and printed street-index entries
   ("Almond,", "Academy, N....") are dropped. VLM-read labels fill gaps (at most
   two per name: a looping VLM repeats one).
4. **Seeds.** Two labels of streets that meet in OSM imply the junction at the
   intersection of their label lines; the VLM also points at named crossings.
5. **Rough fit.** Every 2-point similarity implied by seeds is scored by how
   many printed labels land near their own modern street (± 15 m at this stage)
   plus seed agreement.
6. **Labels-first fit.** From the rough fit, each printed label is snapped onto
   its own modern street centreline (ICP, ± 8 m). Names sit on centrelines, so
   this is more precise than VLM junction pinpoints (which lean toward street
   edges). Accepted if the gates (below) pass — no zoomed VLM calls needed.
7. **Fallback: junction fit.** Otherwise: project every modern intersection
   through the rough fit, let the VLM pinpoint each on a zoomed crop, RANSAC
   (label-line junctions weighted 3×), ICP against label centrelines; if that
   fails the gates, one more labels-only attempt.
8. **Gates.** A part is emitted only if
   * ≥ max(3, 25 %) of its labels sit on their streets (± 8 m),
   * those streets run in ≥ 2 directions (≥ 30° apart), so the fit can't slide,
   * the fitted m/px agrees with a "Scale N ft to an inch" printed inside the
     part (majority of the statements inside it, then the one nearest the
     top — an unsplit inset can carry its own), else one of Sanborn's
     standard scales: implied resolution 355–427 dpi on the canvas's 395-dpi
     grid (111 correct fits fell in 0.925–1.055 of nominal; a campus sheet
     anchored on building names fitted at 1.10).
   Otherwise the part is reported as not georeferenced — no annotation beats a
   wrong one. GCPs are the part outline and labels mapped through the fit.
9. **Fallback: slide (after all canvases).** A declined part whose labels give
   no crossing pair (no label-line junction) but name ≥ 2 parallel streets can
   slide along them. `priv/georef/slide.py` places the family at Sanborn's
   standard scales (50 / 100 ft to the inch at 395 dpi), ranks placements by
   how well modern centrelines fall into printed street corridors, and for the
   top 8 predicts up to 3 named cross streets with mid-block read points. Each
   point is read on a 1200 px crop (OCR, then the VLM only if OCR found no
   street name): naming a street within 20 m confirms, naming a real street
   more than 60 m away contradicts. The best placement with a confirmation and
   no contradiction adds its reads as labels and goes through the normal
   labels-only fit and gates (method `slide`). Scale: the printed one, else the
   class of the previous and next fitted sheets when they agree, else both
   classes with ≥ 2 confirmations required (atlases mix 50 and 100 ft sheets).
   `--no-slide` turns it off.
10. **Retry with a bigger VLM** (`--retry-model qwen38_27b`, before the slide
    pass). Canvases with a declined part are run again with Qwen3.8-27B, which
    reads more street names (~2.5× slower); its parts replace the originals
    only if more of them fit. Locally the model is swapped on the same port.
11. **Atlas consistency (last).** Same-scale sheets tile the town, so two
    same-scale parts whose ground footprints overlap by more than half can't
    both be right. On a regular grid a sheet can fit one block off with every
    label on a parallel street (Vineland Sheet 11 sat 73 % on Sheet 12 and
    passed every per-sheet gate; overlays and seam matching looked fine). If a
    fitted key map (overview) prints one sheet's number inside its footprint,
    that one is kept; otherwise both are declined (`Georef.Consistency`).
12. **Fallback: neighbour placement** (after the slide, before the
    consistency check so a bad placement is still caught). A declined part
    with labels on ≥ 2 modern streets is placed from the fitted sheets around
    it (`Georef.Neighbour`, `priv/georef/neighbour.py`). Scale and rotation are
    priors — the printed scale, else the neighbours' class (as in the slide),
    else the class of the fitted sheets whose numbers are printed at the
    part's edges; rotation = circular median of the fitted sheets mod 90° +
    k × 90° — so each label is a line constraint on the translation. Anchor
    labels are stepped along their street (4 m); positions where labels of ≥ 2
    streets land on theirs (15 m, ±15° direction; a second pass ignores
    direction) are snapped, ranked by labels on streets + corridor score, and
    those covering a fitted footprint by > 50 % dropped. The top 8 are checked
    against every street name on the sheet, OCR'd in 1800 px tiles at 2/3
    resolution (`Ocr.read_tiled/2`; names < 78 px tall are building notes):
    a name printed within 20 m of its street matches, > 60 m contradicts;
    adjacent-sheet numbers must land within 40 m of that sheet's footprint
    (> 150 m contradicts). Accepted only with no contradiction, ≥ 2 name
    reads of which ≥ 1 is informative (on a crossing street when all labels
    are parallel), and no rival ≥ 20 m away with as much support; the final
    fit holds scale and rotation and fits the translation to labels + reads
    (method `neighbour`). Name reads are keyed more strictly than labels: a
    bare "WEST" names nothing (West Avenue or West Boulevard?) and
    direction-only names compare in long form ("S. E. BOULEVARD" = South East
    Boulevard). Fitted parts that the consistency check will decline (Vineland
    Sheet 11) are not used as neighbours. Weaker rules (a junction of two
    labels + an agreeing sheet reference) placed more parts in the prototype
    but are not shipped. Leave-one-out on Vineland (labels cut to 2–3): ~50 %
    of trials placed, 1 of 120 wrong (17 m off). `--no-neighbour` turns it
    off.

## Additions (Nov 2026)

* **No VLM server needed by default.** The neatline is found by image
  processing (`priv/georef/neatline.py`: outermost ruled line with blank
  margin beyond it, within 8.5 % of the edge, else where the drawing starts);
  on 86 sheets the VLM's neatline cut real map content more often (Princeton
  1918 Sheets 6 and 9, Millville Sheet 18). The VLM zoom-in on junction seeds
  is off (`--refine` turns it on): check points held or improved, the
  held-out sample fitted the same parts, at ~10x the speed. It had masked
  a selection weakness: among refined candidate fits the one with most
  labels on streets won, and a weak start could drift in ICP to a rotated fit
  with one more label (Bay Head 1905 Sheet 48: -35 deg, 6 labels vs the
  right fit's 5 labels and 6 junction seeds). Candidates now also score half
  a point per junction seed within 30 m of its modern intersection; on the
  15-atlas batch this fixed W. Ocean Grove 1905 Sheet 61 part 1, declined a
  wrong Bay Head Sheet 47 fit, and added Flemington 7 and Matawan 1. The
  VLM's slide-fallback reads changed no result on the 3 atlases that use
  them (~75 calls). The server is
  started lazily, only for the slide fallback's crop reads (when OCR cannot
  read a crop) or the opt-in flags (`--vlm-neatline`, `--vlm-labels`,
  `--vlm-points`, `--refine`, `--retry-model`); an unreachable server leaves
  those crops unread.
* **Corridor alignment** (`priv/georef/align.py`, last pass, `--no-align`):
  every accepted fit is refined by point-to-line ICP pairing modern
  centreline samples that lie in printed street corridors with the corridor
  centre, plus each label with its own street (label weight 30, so a grid
  cannot slip a street over); kept if no label leaves its street, at most
  15 m / 3 deg. A blind search maximising corridor metres was worse (modern
  streets through old blocks steer it) and corridors without label anchors
  were mixed. Check points: Paulsboro 1.6 -> 1.2 m, Cresskill 1.7 -> 1.2,
  Hohokus 1.7 -> 1.6, Hightstown 3.2 -> 3.4; held-out and 15-atlas batch:
  same parts fitted, 92 of 97 aligned, nothing moved over 7 m. OIM human
  GCPs (same code, align off -> on): Clayton 5.3 -> 3.6, Carneys Point
  17.1 -> 14.0, Mantua 2.0 -> 1.6, Westville 5.4 -> 5.1; Mullica Hill
  6.4 -> 8.0 and Glassboro 13.5 -> 14.8 worse; rest flat.
* **No VLM for names or junctions by default.** On the check points and the
  oldinsurancemaps.net set the VLM's label reading and junction pointing
  added nothing (equal accuracy, one fewer wrong fit without) at ~3× the
  time; the names it alone read were mostly PP-OCR pipeline misses (33-name
  benchmark, below). The VLM still finds the neatline and runs the slide.
* **OCR.** On the 33 street names only the VLM had read (held-out sample),
  PP-OCRv5 detection at 2400 px tiles finds 24; PP-OCRv6 small recognition
  reads 25 at ~1 s/tile (v5: 22). Tried and dropped: GLM-OCR (25, no boxes),
  PaddleOCR-VL-1.6 spotting (21–24, 6 s/tile), OvisOCR3, Chandra OCR 2 (slow),
  PP-DocLayoutV3 (calls a map an "image"), grayscale, ±45° passes (+1 name
  for 2× time).
* **Junk labels.** The town's own name is dropped near title lettering or
  below street-name size; words that also name buildings, colours of the key,
  materials or structures (CHURCH, GREEN, GARAGE, BRIDGE, SCALE, …) count as
  streets only at street-name size (≥ 100 px at 395 dpi); numbered streets
  ("3RD", OCR "7H") are read and matched exactly. Among candidate fits, small
  lettering counts less.
* **Named buildings.** Named OSM building footprints are label targets: a
  label inside its building is on target, pulled to the centre of a compact
  footprint (< 50 m). Fits campuses (Princeton 1918 Sheet 13, the Prospect
  Avenue clubs) and helps sheets with named churches, mills and schools.
* **Street renames** learned per atlas (`Georef.Renames`): street-size words
  lying along a modern centreline on fitted sheets vote for that street;
  agreeing votes (≥ 2, ≥ 75 %) alias the name for the declined sheets. Votes
  and renames are kept in the report.
* **Scans at other resolutions** (LoC: 300 dpi) get a virtual 395-dpi pixel
  grid (`Manifest.px_scale`), so all thresholds hold.
* **Parts**: collinear rule pieces interrupted by a compass rose are joined
  (gaps up to 25 % of the sheet between two long rules on one line:
  Allendale 1924 Sheet 4); each part's outline grows out to the page border
  but never past a rule into another part (every pixel goes to the nearest
  part core; outlines used to overlap their neighbours by 3–8 %, drawing a
  sliver of an inset with the main part's fit); parts down to 3 % of the
  page are kept (small boxed insets: Roebling 1928 Sheet 3, Cranford Sheet 1,
  Stewartsville 1924 Sheet 2).
* **Scales**: "Scale, 120 Feet…" (comma) and OCR "IZO" (Z for 2) are read
  (120 ft is accepted only when printed: as a default standard scale it let
  a 114 ft wrong fit of Spotswood 1910 Sheet 1, a 50 ft sheet, pass); a part with no statement of its own also tries
  the sheet's stated scales, and the neighbour pass uses a fitted sibling
  part's scale (60 ft used to be rounded to the 50 ft class). Fixed wrong
  fits on W. Ocean Grove 1905 Sheet 62 and Manasquan 1921 Sheet 85 (both
  120 ft, fitted near 100 ft before).
* **Parcels (tried, not adopted).** The NJ statewide parcel composite
  (NJOGIS ArcGIS feature service, public) still follows Sanborn lot lines in
  old town centres to ~2 m. Matching a sheet's drawn lines (dark lines that
  survive a 0.4-inch line opening) to rasterised parcel boundaries by FFT
  normalised cross-correlation over scale × rotation × translation
  (`tmp/georef_scratch/tools/parcelmatch.py`, ~15 s per scale at 2 m/px):
  - labels-free it places Princeton 1918 Sheets 9 and 15 within 1–8 m, and
    with the sheet's few labels as constraints (each within 30 m of its named
    street) Sheet 18 part 1 within 1–4 m;
  - but on the parts that actually fail (Princeton 17, 18 insets, 20) the
    lots were redeveloped or estates subdivided: the best wrong pose scores
    as high (0.44) as true poses elsewhere (0.35–0.48), so no safe threshold;
  - as a local refinement of accepted fits (±3°, ±4 %, 80 m; applied if
    NCC ≥ 0.2 and move ≤ 30 m) against human GCPs: Carneys Point p2
    23.5 → 2.5 m, Pitman 12.5 → 9.7, Clayton 5.3 → 3.4, but Westville layers
    1–4 m worse and the rest ±1 m — no net gain on the held-out set.
* **Placement from fitted neighbours (tried, not adopted).** Leave-one-out on
  Princeton 1918 with one street name per part (as on the declined parts):
  - adjacent-sheet numbers printed at the edges, required to land on or
    within 40–80 m of that sheet's fitted footprint, pin a part only to
    ~100 m (footprints are 300–400 m across): top candidate ≤ 30 m on 3/19;
  - matching the part's lot/block lines against a mosaic of the other fitted
    sheets' lines (`tmp/georef_scratch/tools/mosaicmatch.py`; FFT NCC over
    the overlap only): neighbouring sheets do share linework (35–60 % of a
    sheet's lines lie within 4 m of a neighbour's), but the overlap is a thin
    edge strip, and the top candidate is ≤ 30 m on 5/20; with the sheet's own
    layer left in, the true pose scores 0.67 at 1 m, so the geometry is right
    and the evidence is just too thin. Sheet 17 is three separate stretches of
    Alexander Street with one name each; Sheet 18's parts are separate insets.
* **External cross-check.** A colleague's agent-made georeferences of 343 NJ
  Figgy atlases (eliotjordan.github.io `sanborn/data/atlases/*.json`: IIIF
  georef annotations with named-junction GCPs plus per-sheet descriptions)
  agree with ours to ≤ 5 m on 18/27 shared parts, ≤ 10 m on 20, ≤ 25 m on
  23 (`tmp/georef_scratch/tools/cmp_colleague.py`). It is unverified AI
  output, not ground truth: it is used only to flag sheets worth inspecting,
  and every fix is decided from our own evidence (OSM overlays, the printed
  sheet). Nothing from it (GCPs, notes, renames) feeds the pipeline.

## Evaluation

**Check points** (`priv/georef/eval/truth/`, `evalgeo.py`): hand-labelled
pixel → OSM intersections on Paulsboro 1886, Cresskill 1914, Hightstown 1916
and Ho-Ho-Kus 1928 (34 points). Metric: error in metres of the affine Allmaps
would fit, at the check points. Noise floor ≈ 1.7–4.5 m per sheet.

**Label-free collection checks** for atlases without check points:
* `seams.py` — where two sheets' masks overlap on the ground, render both onto
  one ground grid and template-match 2-D-structured patches; the median offset
  is the seam gap between the two fits (plain SIFT fails: line drawings slide
  along streets, and repeated glyphs match everywhere).
* `labelfree.py` — per part: status, labels on streets, implied dpi from the
  printed scale (outliers flag wrong scales), seam gaps.
* `overlay.py` — modern OSM drawn through the fit, for eyeballing.

Results (8B model):

| | Check points: median / p90 / max | Tuning sample (12 atlases) | Held-out sample (11 atlases) |
|---|---|---|---|
| junction fit, 40 % gate (morning) | 2.8 / 4.9 / 11.1 m, 32/34 covered | 20 / 41 parts | — |
| + fixes, labels-first, 25 % + scale gates | 2.0 / 3.3 / 12.2 m, 34/34 | 25 / 42 parts | 26–28 / 40 parts |
| no VLM labels, v6 OCR, buildings (Nov 25) | 1.8 / 3.2 / 12.4 m, 34/34 | — | 24 / 41 parts, 1 wrong |

**Human ground truth** (`tmp/georef_scratch/tools/oim.py`): oldinsurancemaps.net
publishes its hand-made control points as IIIF Georeference annotations (CC0)
at `https://oldinsurancemaps.net/iiif/mosaic/<loc id>/main-content/`. The
harness builds a manifest from the LoC image services, runs the pipeline and
scores every human control point inside one of our parts (metres to the
human affine; a layer is WRONG at > 25 m median). Their own residuals are
reported too — some human fits are off by 15–35 m. Six Gloucester County
towns: 2–8 m where the human fit is clean, one wrong fit (Swedesboro 1898
Sheet 2: renamed main street, four labels).

No wrong fit has been seen in the accepted output since the scale gate (the
12 m worst check point is a suspect hand label). Seam gaps between neighbouring
sheets: 2–10 m. Whole Vineland atlas (28 parts): 18 georeferenced.

Key measured facts that shaped the design:
* VLM point grounding is precise (≈ 2–7 m) but its *identity* is unreliable,
  so identity comes from printed labels and geometry.
* "Verify" checks must be able to fail: a VLM confirming a predicted junction
  is self-confirming. A VLM asked whether an OSM overlay is aligned answered
  "aligned" for 100 m-shifted fits too (Qwen3.6, with or without thinking).
* Qwen3.5/3.6 grounding treats a `"label"` field as the queried category and
  echoes the prompt into it; the label prompt uses `"text"`. With that fixed,
  Qwen3.6 ≈ 8B in accuracy at ~1.7× the time.
* Aligning modern centrelines to the printed street corridors pixel-wise
  separates good from shifted fits locally, but its optimum sits a few metres
  off (modern centrelines ≠ historic corridors) — it made fits worse.
* Per call, image prefill dominates (~5.5 s for a 1536 px image on an M2 Max or
  M1 Ultra), so throughput comes from running servers in parallel.

## Known limits / next steps

* Declined parts are mostly small insets and sheets with few readable street
  names in two directions (industrial yards, rural edges, subdivisions whose
  paper streets were never built). These need non-name evidence: placement from
  fitted neighbouring sheets (key map or shared edge strips) plus street-pattern
  matching.
* VLM label reading varies between runs/builds and can flip a marginal sheet.
* Index sheets / small-scale overview maps aren't targeted (their names are too
  small and one-directional to fit from labels).
* OCR and part-splitting run as Python helpers; a port to Ortex/Evision (or
  Transmuter) would keep everything in the BEAM.
