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
mix georef ... --no-labels-first                    # ablation: junction fit only
```

Writes `<out>.json` (AnnotationPage) and `<out>.report.json` (debug data). In
dev, files under `tmp/georef/` are served with CORS at
`http://localhost:4000/georef/<name>.json` so Allmaps can load them with
`https://viewer.allmaps.org/?url=...`.

## Local components

| What | How | Code |
|---|---|---|
| Vision-language model | `llama-server` (llama.cpp) with Qwen3-VL-8B (default) or Qwen3.6-35B-A3B GGUF; started on demand, or remote via `GEOREF_HOST` | `Georef.Vlm` |
| OCR (text + rotated boxes) | PP-OCR det/rec ONNX models via RapidOCR, `priv/georef/ocr.py` under `uv`; upright + 90°-rotated pass | `Georef.Ocr` |
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
     part: implied scan resolution 350–450 dpi (Princeton's scans are 392–398).
   Otherwise the part is reported as not georeferenced — no annotation beats a
   wrong one. GCPs are the part outline and labels mapped through the fit.

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
