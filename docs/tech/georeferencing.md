# Automatic georeferencing prototype

Goal: given a IIIF manifest of a scanned map (initially Sanborn fire insurance
sheets from maps.princeton.edu), produce a
[IIIF Georeference](https://iiif.io/api/extension/georef/) AnnotationPage that
opens in [Allmaps](https://viewer.allmaps.org) — using only local compute.

```
mix georef https://maps.princeton.edu/catalog/princeton-t148fm04w
mix georef <manifest-url> --canvases 0,1 --out tmp/georef/paulsboro
GEOREF_MODEL=qwen36_35b mix georef ...      # choose the local VLM
```

Writes `<out>.json` (AnnotationPage) and `<out>.report.json` (debug data). In
dev, files under `tmp/georef/` are served with CORS at
`http://localhost:4000/georef/<name>.json` so Allmaps can load them with
`https://viewer.allmaps.org/?url=...`.

## Local components

| What | How | Code |
|---|---|---|
| Vision-language model | `llama-server` (llama.cpp) with Qwen3-VL-8B or Qwen3.6-35B-A3B GGUF, started on demand | `Georef.Vlm` |
| OCR (text + rotated boxes) | PP-OCR det/rec ONNX models via RapidOCR, `priv/georef/ocr.py` under `uv` | `Georef.Ocr` |
| Heavy-rule detection | OpenCV morphology + Hough, `priv/georef/parts.py` under `uv` | `Georef.Parts` |
| Modern streets/rail/water | Geofabrik state `.osm.pbf` clipped with `osmium` (Overpass fallback) | `Georef.Osm` |
| Geometry | similarity fit, RANSAC, label ICP | `Georef.Geometry` |

Models and OSM extracts are cached under `~/.cache/dpul_georef`.

## Pipeline (per canvas)

1. **Where to look.** The catalog bbox is only a hint (Hightstown's points
   at Hamilton, ~15 km away). The title's place name is looked up in OSM
   places; if a same-named place is inside the padded bbox we use the bbox,
   otherwise a box around the place.
2. **Neatline + parts.** The VLM finds the printed border. Heavy rules —
   Sanborn's convention for separating areas that are *not* geographically
   continuous (a detached works "1¼ miles north east of Paulsboro", a second
   street drawn below a divider) — split the sheet into parts. Each part is
   georeferenced on its own and gets its own annotation with the part polygon
   as its SvgSelector mask. Parts that cannot be fit are left out.
3. **Labels.** OCR reads every text line with a rotated box. Tokens that
   fuzzy-match a modern street / railway / waterway name become labels with a
   position *and direction*. VLM-read labels fill gaps.
4. **Seeds.** Street names are printed along their street, so two labels of
   streets that meet in OSM imply the junction at the intersection of their
   label lines (identity from the printed names). The VLM also points at named
   crossings; those are precise-ish but often the *wrong* crossing.
5. **Rough fit.** Every 2-point similarity implied by seeds is scored by how
   many printed labels land on their own modern street (± 8 m) plus seed
   agreement. Label agreement is the independent check: a wrong fit cannot
   put many labels on the right streets.
6. **Predict and verify.** Through the rough fit, every modern intersection in
   the part is projected onto the scan; the VLM pinpoints it on a zoomed crop.
7. **Final fit.** RANSAC (label-line junctions weighted 3×, as they measured
   ~2× more accurate than VLM pinpoints), then ICP against the labels'
   modern street centrelines. GCPs are written at the observed junction
   pixels with world coordinates from that fit; `transformation` is
   polynomial order 1.
8. **Gate.** A part is emitted only if ≥ 3 GCPs and ≥ max(3, 40 %) of its
   labels sit on their streets. Otherwise it is reported as not
   georeferenced — no annotation beats a wrong one.

## Evaluation

Hand-labelled check points (pixel → OSM intersection, never seen by the
pipeline) on Paulsboro 1886 sheets 1–2, Cresskill 1914 sheet 2 (dev set) and
Hightstown 1916 sheet 3 (held out). Metric: error in metres of the affine
Allmaps would fit from the emitted GCPs, at the check points. A similarity fit
to the check points themselves leaves ~1.7 m (label/OSM noise floor).
Overlays of modern OSM streets drawn through the fit on each sheet are used
for sheets without check points.

Milestones (median / max error at check points, 8B model):

| Change | Paulsboro | Cresskill |
|---|---|---|
| VLM names + VLM points intersections | not georeferenced | not georeferenced |
| predict-and-verify | 62 m (wrong fit accepted) | 7.0 / 8.4 m |
| label-on-street scoring | rejected (no wrong output) | 3.1 / 3.3 m |
| OCR labels + label-line junctions | 6.6 / 11.2 m | 5.2 / 5.9 m |
| label ICP + source-weighted RANSAC | 2.0 / 3.8 m | 3.5 / 4.1 m |

Held out (Hightstown 1916): 2.3 m at check points; 7 of 9 sheets fit, all at
a consistent 0.039–0.041 m/px. Heavy-rule parts fixed a multi-part sheet that
a single fit got wrong.

Key measured facts that shaped the design:
* VLM point grounding is precise (≈ 2–7 m) but its *identity* is unreliable
  (8B: right crossing 6/11; Qwen3.6: 10/11). So identity comes from printed
  labels and geometry, and the VLM only pinpoints locally.
* "Verify" checks must be able to fail: asking a VLM to confirm a predicted
  junction is self-confirming when the prediction is wrong.

## Known limits / next steps

* Street renames (1886 "Main" = modern Broad) are handled implicitly through
  geometry, but a sheet whose names are mostly gone from OSM will be declined.
* Index sheets / small-scale overview maps aren't targeted yet.
* OCR and part-splitting run as Python helpers; a port to Ortex/Evision (or
  Transmuter) would keep everything in the BEAM.
