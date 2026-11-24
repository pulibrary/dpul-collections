defmodule DpulCollections.Georef do
  @moduledoc """
  Prototype: automatically georeference the canvases of a IIIF map manifest
  and emit a IIIF Georeference AnnotationPage. See docs/tech/georeferencing.md.

  Per canvas:
    1. find the neatline (VLM) and split the sheet into parts along heavy
       rules (Sanborn's convention for areas that are not continuous)
    2. read street/rail/water labels with OCR (+ VLM fallback) and match them
       to a local OSM gazetteer; labels give junction seeds by intersecting
       label lines
    3. per part: pick a rough similarity by how many labels land on their
       own modern street, predict-and-verify modern intersections on zoomed
       crops, then RANSAC + label-ICP for the final fit
    4. each part that passes the label check becomes one annotation, masked
       to the part polygon
  """
  require Logger

  alias DpulCollections.Georef.{Annotation, Geometry, Manifest, Mask, Ocr, Osm, Parts, Vlm}

  @overview 1536
  @min_label_hits 3
  # Measured on a 12-atlas sample: 0.4 declined correct fits with 4-6 of
  # 11-17 labels on their streets; at 0.25 the one wrong fit it let through
  # was caught by the printed-scale check below.
  @min_label_fraction 0.25
  # Princeton's Sanborn scans: printed scale + fitted m/px imply 392-398 dpi.
  @scan_dpi {350, 450}
  @label_tolerance 8.0
  @rough_label_tolerance 15.0
  @scale_range {0.005, 2.0}
  @zoom 768

  def run(url, opts \\ []) do
    Vlm.ensure_server()
    manifest = Manifest.fetch(url)
    bbox = search_bbox(manifest)
    osm = Osm.load(bbox)

    canvases =
      case Keyword.get(opts, :canvases) do
        nil -> manifest.canvases
        idx -> Enum.map(idx, &Enum.at(manifest.canvases, &1))
      end

    results =
      Enum.flat_map(canvases, fn canvas ->
        Logger.info("georef: #{manifest.label} / #{canvas.label}")
        georeference_canvas(canvas, osm, opts)
      end)

    ok = Enum.filter(results, &(&1.status == :ok))
    %{manifest: manifest, osm: osm, results: results, annotation: Annotation.page(manifest, ok)}
  end

  @doc "Returns one result per part of the sheet."
  def georeference_canvas(canvas, osm, opts \\ []) do
    overview = fetch_image(Manifest.image_url(canvas, "full", @overview))
    full_region = {0, 0, canvas.width, canvas.height}

    neatline = neatline(canvas, overview)
    parts = Parts.split(canvas, neatline, &fetch_image/1)

    # Street-name labels and where they are printed. Labels sit on their
    # street, which gives an identity check independent of junction pointing.
    # OCR (rotated boxes, precise) is the primary label source; VLM labels
    # fill in what OCR missed.
    ocr_tokens = Ocr.read(canvas, &fetch_image/1)
    ocr_pts = ocr_labels(ocr_tokens, osm)
    scales = printed_scales(ocr_tokens)
    vlm_labels = read_labels(overview, full_region)

    vlm_matched =
      vlm_labels |> Enum.map(& &1.name) |> Enum.uniq() |> match_names(osm) |> Map.new()

    vlm_pts =
      for l <- vlm_labels,
          k = vlm_matched[l.name],
          not Enum.any?(ocr_pts, &(&1.key == k and Geometry.dist(&1.px, l.px) < 400)),
          do: l |> Map.put(:key, k) |> Map.put(:source, :vlm)

    label_pts = ocr_pts ++ vlm_pts
    matched = label_pts |> Enum.map(&{&1.name, &1.key}) |> Enum.uniq_by(&elem(&1, 1))
    pairs = candidate_pairs(matched, osm)

    # Seeds: label-line junctions (reliable identity) + VLM-located named
    # crossings (precise-ish, identity often wrong). They only propose fits.
    seeds =
      (label_junctions(label_pts, osm, canvas) ++ locate_each(pairs, overview, full_region))
      |> maybe_refine(canvas, opts)

    parts
    |> Enum.with_index(1)
    |> Enum.map(fn {polygon, i} ->
      inside = &Mask.inside_polygon?(&1, polygon)
      part_labels = Enum.filter(label_pts, &inside.(&1.px))
      part_seeds = Enum.filter(seeds, &inside.(&1.px))

      label = if length(parts) > 1, do: "#{canvas.label} (part #{i})", else: canvas.label

      # Printed "Scale N Ft. to an Inch" inside this part (an inset's scale
      # often differs from the main map's, so no sheet-wide fallback).
      printed = Enum.find_value(scales, &(inside.(&1.px) && &1.ft))

      %{
        canvas: canvas,
        part: i,
        label: label,
        mask: polygon,
        labels: part_labels,
        printed_scale_ft: printed
      }
      |> Map.merge(fit_part(canvas, osm, polygon, part_labels, part_seeds, printed, opts))
    end)
  end

  defp fit_part(canvas, osm, polygon, label_pts, seeds, printed_ft, opts) do
    seed_candidates = to_candidates(seeds, osm)
    rough = best_hypothesis(seed_candidates, label_pts, osm)
    fraction = Keyword.get(opts, :min_label_fraction, @min_label_fraction)
    needed = max(@min_label_hits, ceil(fraction * length(label_pts)))

    # Labels first: printed names sit on street centrelines, so snapping them
    # onto their modern streets is more precise than VLM junction pinpoints
    # (which lean ~7 m toward a street edge). On the check-point maps:
    # median 1.9 m vs 2.5 m, and no zoomed VLM calls needed.
    labels_fit =
      rough && Keyword.get(opts, :labels_first, true) &&
        labels_only_fit(rough.t, label_pts, osm, polygon, needed, printed_ft)

    if labels_fit do
      Map.merge(%{located: seeds, rough: Map.delete(rough, :t)}, labels_fit)
    else
      junction_fit(
        canvas,
        osm,
        polygon,
        label_pts,
        seeds,
        seed_candidates,
        rough,
        needed,
        printed_ft,
        opts
      )
    end
  end

  defp junction_fit(
         canvas,
         osm,
         polygon,
         label_pts,
         seeds,
         seed_candidates,
         rough,
         needed,
         printed_ft,
         opts
       ) do
    # Predict-and-verify: geometry says where each modern intersection should
    # be; the VLM only pinpoints it on a zoomed crop.
    verified = if rough, do: verify_predictions(rough.t, osm, canvas, polygon), else: []
    candidates = seed_candidates ++ Enum.map(verified, &Map.put(&1, :key, &1.keys))
    base = %{located: seeds ++ verified, rough: rough && Map.delete(rough, :t)}

    final =
      rough &&
        Geometry.ransac(candidates,
          threshold: Keyword.get(opts, :threshold, 10.0),
          scale_range: @scale_range,
          # label-line junctions are ~2x more accurate than VLM pinpoints
          weight: fn c -> if c[:source] == :labels, do: 3, else: 1 end
        )

    label_check = with {:ok, t, _, _} <- final, do: label_score(t, label_pts, osm)

    scale_ok = with {:ok, t, _, _} <- final, do: scale_consistent?(Geometry.scale(t), printed_ft)

    case final do
      {:ok, t0, inliers, residuals}
      when length(inliers) >= 3 and label_check >= needed and scale_ok ->
        # Labels sit on street centrelines (~1-3 m) — more precise than VLM
        # junction pinpoints (measured ~7 m, often on a street edge) — so let
        # them refine the fit, anchored by label-line junctions when there are
        # enough. GCPs go at the observed junction pixels with world coords
        # from that fit.
        curves = for l <- label_pts, g = osm.groups[l.key], do: {l.px, g.segments}
        from_labels = Enum.filter(inliers, &(&1[:source] == :labels))
        fixed = if length(from_labels) >= 2, do: from_labels, else: inliers

        t =
          Geometry.refine_with_curves(t0, Enum.map(fixed, &{&1.px, &1.xy}), curves,
            tolerance: @label_tolerance
          )

        gcps =
          Enum.map(inliers, fn c ->
            %{
              px: c.px,
              lonlat: Geometry.to_lonlat(osm.projection, Geometry.transform(t, c.px)),
              label: c.label
            }
          end)

        Map.merge(base, %{
          status: :ok,
          transform: t,
          projection: osm.projection,
          gcps: gcps,
          residuals: residuals,
          label_hits: label_check,
          scale: Geometry.scale(t)
        })

      other ->
        case rough && labels_only_fit(rough.t, label_pts, osm, polygon, needed, printed_ft) do
          %{} = fit ->
            Logger.info(
              "georef: #{canvas.label} part fitted from labels (#{fit.label_hits} on their streets) after the junction fit failed"
            )

            Map.merge(base, fit)

          _ ->
            Logger.warning(
              "georef: #{canvas.label} part not georeferenced (#{inspect(decline_reason(other))}, " <>
                "label hits #{inspect(label_check)}/#{needed} needed)"
            )

            Map.merge(base, %{status: :failed, gcps: [], label_hits: label_check})
        end
    end
  end

  # Snap each printed label onto its own modern street, starting from the
  # rough fit; accept only if enough labels land on their streets, those
  # streets run in at least two directions (labels on parallel streets alone
  # would let the fit slide along them), and the scale matches the printed
  # one. GCPs are the part outline and the labels, mapped through the fit.
  defp labels_only_fit(t0, label_pts, osm, polygon, needed, printed_ft) do
    curves = for l <- label_pts, g = osm.groups[l.key], do: {l.px, g.segments}
    t = Geometry.refine_with_curves(t0, [], curves, tolerance: @label_tolerance)

    hits = label_score(t, label_pts, osm)

    if hits >= needed and crossing_streets?(t, label_pts, osm) and
         scale_consistent?(Geometry.scale(t), printed_ft) do
      pts =
        Enum.map(polygon, &%{px: &1, label: "outline"}) ++
          Enum.map(label_pts, &%{px: &1.px, label: &1.name})

      %{
        status: :ok,
        method: :labels,
        transform: t,
        projection: osm.projection,
        gcps:
          Enum.map(pts, fn p ->
            %{
              px: p.px,
              lonlat: Geometry.to_lonlat(osm.projection, Geometry.transform(t, p.px)),
              label: p.label
            }
          end),
        residuals: [],
        label_hits: hits,
        scale: Geometry.scale(t)
      }
    end
  end

  # Directions (mod 180 degrees) of the modern streets under the labels that
  # landed on them must differ by at least 30 degrees somewhere.
  defp crossing_streets?(t, label_pts, osm) do
    dirs =
      for l <- label_pts,
          g = osm.groups[l.key],
          w = Geometry.transform(t, l.px),
          {{x1, y1}, {x2, y2}} =
            seg = Enum.min_by(g.segments, &Geometry.point_segment_dist(w, &1)),
          Geometry.point_segment_dist(w, seg) <= @label_tolerance,
          do: :math.atan2(y2 - y1, x2 - x1)

    Enum.any?(for a <- dirs, b <- dirs, do: angle_between(a, b) > 30)
  end

  @doc """
  Does a fit's m/px agree with the part's printed "N ft to an inch" at the
  scan resolution? A wrong fit that still puts a few labels on same-named
  streets is usually off in scale. True when no scale was printed.
  """
  def scale_consistent?(_m_per_px, nil), do: true

  def scale_consistent?(m_per_px, ft) do
    {lo, hi} = @scan_dpi
    dpi = ft * 0.3048 / m_per_px
    dpi >= lo and dpi <= hi
  end

  @doc """
  Choose a rough fit among every 2-point similarity the seeds imply. Score =
  printed labels that land on their own modern street + seed inliers. A fit
  must put at least #{@min_label_hits} labels on their streets to be trusted.
  """
  def best_hypothesis(seed_candidates, label_pts, osm) do
    seed_candidates
    |> Geometry.hypotheses(scale_range: @scale_range, min_px_separation: 300)
    |> Enum.map(fn t ->
      seeds = Geometry.inliers_of(t, seed_candidates, 30.0)

      %{
        t: t,
        # A 2-junction rough fit is only approximate, so count labels near
        # their street loosely here; acceptance re-checks at @label_tolerance
        # after refinement.
        label_hits: label_score(t, label_pts, osm, @rough_label_tolerance),
        seed_inliers: length(seeds),
        seeds: seeds
      }
    end)
    |> Enum.filter(&(&1.label_hits >= @min_label_hits and &1.seed_inliers >= 2))
    |> Enum.max_by(&{&1.label_hits + &1.seed_inliers, &1.seed_inliers}, fn -> nil end)
    |> case do
      nil ->
        nil

      best ->
        # refit on the hypothesis' seed inliers
        t = Geometry.fit_similarity(Enum.map(best.seeds, &{&1.px, &1.xy})) || best.t

        Logger.info(
          "georef: rough fit labels=#{best.label_hits} seeds=#{best.seed_inliers} scale=#{Float.round(Geometry.scale(t), 4)}"
        )

        %{best | t: t} |> Map.delete(:seeds)
    end
  end

  @doc """
  Printed scale statements ("SCALE 100FT. TO AN INCH") as feet per inch. OCR
  confuses I/l with 1 and O with 0 in these, so digits are normalised.
  """
  def printed_scales(tokens) do
    for t <- tokens,
        [_, digits] <- [Regex.run(~r/scale\s*([0-9IOlo]{2,4})\s*f/i, t.text)],
        {ft, ""} <- [
          digits
          |> String.replace(~r/[Il]/, "1")
          |> String.replace(~r/[Oo]/, "0")
          |> Integer.parse()
        ],
        do: %{ft: ft, px: t.center}
  end

  @doc "OCR tokens that name a modern street/railway/waterway, with direction."
  def ocr_labels(tokens, osm) do
    for t <- tokens,
        t.score >= 0.75,
        String.length(String.replace(t.text, ~r/[^\p{L}]/u, "")) >= 3,
        not index_entry?(t.text),
        key = Osm.match_name(osm, t.text),
        do: %{name: t.text, key: key, px: t.center, angle: t.angle, source: :ocr}
  end

  # Entries of a printed street index ("Academy, N....", "Almond,") are not
  # on their street; map labels never contain a comma or dot leaders.
  defp index_entry?(text), do: Regex.match?(~r/,|\.\./, text)

  @doc """
  Street names are printed along their street, so each label defines a line.
  Two labels of different, non-parallel streets that meet in OSM imply the
  junction at the intersection of their lines. Identity comes from the printed
  names, so these seeds are far more trustworthy than asking the VLM to find a
  named crossing.
  """
  def label_junctions(label_pts, osm, canvas) do
    meets = MapSet.new(osm.intersections, & &1.keys)
    reach = 0.5 * max(canvas.width, canvas.height)

    for a <- label_pts,
        b <- label_pts,
        a.key < b.key,
        a.angle != nil and b.angle != nil,
        MapSet.member?(meets, {a.key, b.key}),
        angle_between(a.angle, b.angle) > 25,
        {x, y} = px <- List.wrap(line_intersection(a, b)),
        x >= 0 and y >= 0 and x <= canvas.width and y <= canvas.height,
        Geometry.dist(px, a.px) < reach and Geometry.dist(px, b.px) < reach do
      %{
        keys: {a.key, b.key},
        label: "#{a.name} | #{b.name}",
        px: px,
        coarse_px: px,
        source: :labels
      }
    end
    |> Enum.uniq_by(fn %{keys: k, px: {x, y}} -> {k, round(x / 300), round(y / 300)} end)
  end

  # acute angle between two undirected lines, degrees
  defp angle_between(a, b) do
    d = abs(a - b) |> :math.fmod(:math.pi())
    min(d, :math.pi() - d) * 180 / :math.pi()
  end

  defp line_intersection(%{px: {x1, y1}, angle: a1}, %{px: {x2, y2}, angle: a2}) do
    {dx1, dy1} = {:math.cos(a1), :math.sin(a1)}
    {dx2, dy2} = {:math.cos(a2), :math.sin(a2)}
    den = dx1 * dy2 - dy1 * dx2

    if abs(den) < 1.0e-6 do
      nil
    else
      t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / den
      {x1 + t * dx1, y1 + t * dy1}
    end
  end

  def label_score(t, label_pts, osm, tolerance \\ @label_tolerance) do
    Enum.count(label_pts, fn l ->
      Osm.distance_to(osm, l.key, Geometry.transform(t, l.px)) <= tolerance
    end)
  end

  defp maybe_refine(located, canvas, opts) do
    if Keyword.get(opts, :refine, true), do: Enum.map(located, &refine(&1, canvas)), else: located
  end

  defp to_candidates(located, osm) do
    for l <- located,
        i <- Enum.filter(osm.intersections, &(&1.keys == l.keys)) do
      %{key: l.keys, px: l.px, xy: i.xy, lonlat: i.lonlat, label: l.label, source: l[:source]}
    end
  end

  @verify_prompt """
  This is a zoomed-in crop of a historical fire insurance map. Streets are drawn as two \
  parallel lines. If two streets cross or meet near the centre of this image, point to the \
  centre of that intersection. If there is no street intersection near the centre, answer \
  {"point_2d": null}.
  Answer only with JSON: {"point_2d": [x, y]}
  """

  @doc """
  Project every modern intersection into the sheet through the rough fit and
  ask the VLM to pinpoint it on a zoomed crop. Intersections whose predictions
  are too close to another distinct intersection are skipped as ambiguous.
  Returns located maps carrying the exact OSM point they verify.
  """
  def verify_predictions(t, osm, canvas, polygon, opts \\ []) do
    side = Keyword.get(opts, :crop, 1200)
    {l, top, r, b} = Mask.bbox(polygon)
    margin = side * 0.25

    predictions =
      osm.intersections
      |> Enum.map(&Map.put(&1, :pred, Geometry.invert(t, &1.xy)))
      |> Enum.filter(fn %{pred: {u, v} = p} ->
        u > l + margin and u < r - margin and v > top + margin and v < b - margin and
          Mask.inside_polygon?(p, polygon)
      end)
      |> merge_coincident()

    ambiguous_px = side * 0.3

    unambiguous =
      Enum.reject(predictions, fn p ->
        Enum.any?(predictions, &(&1 != p and Geometry.dist(&1.pred, p.pred) < ambiguous_px))
      end)

    # Spread at most 30 checks across the part.
    every = max(1, ceil(length(unambiguous) / 30))

    unambiguous
    |> Enum.sort_by(& &1.pred)
    |> Enum.take_every(every)
    |> Enum.flat_map(fn i ->
      {u, v} = i.pred
      region = crop_region(canvas, {u, v}, side)
      image = fetch_image(Manifest.image_url(canvas, region, @zoom))

      case image
           |> Vlm.ask_json(@verify_prompt, max_tokens: 64, schema: Vlm.point_schema())
           |> parse_point() do
        {x, y} ->
          px = to_px({x, y}, region)
          {a, b} = i.keys

          if Geometry.dist(px, i.pred) < side * 0.35,
            do: [
              %{
                keys: i.keys,
                label: "#{a} & #{b}",
                px: px,
                coarse_px: i.pred,
                xy: i.xy,
                lonlat: i.lonlat,
                source: :verify
              }
            ],
            else: []

        _ ->
          []
      end
    end)
  end

  # Several OSM name pairs can describe one junction (e.g. a street changing
  # name at a crossing); keep one entry per physical point.
  defp merge_coincident(preds) do
    Enum.reduce(preds, [], fn p, acc ->
      if Enum.any?(acc, &(Geometry.dist(&1.xy, p.xy) < 8.0)), do: acc, else: [p | acc]
    end)
  end

  defp decline_reason(nil), do: :no_rough_fit
  defp decline_reason({:ok, _, inliers, _}) when length(inliers) < 3, do: :too_few_inliers
  defp decline_reason({:ok, _, _, _}), do: :too_few_labels_on_streets_or_scale_mismatch
  defp decline_reason(other), do: other

  # Step 1: names --------------------------------------------------------------

  @labels_prompt """
  This is a sheet from a historical fire insurance map. Find every printed name of a \
  street, avenue, road, alley, railroad or waterway (river, creek, canal). For each printed \
  occurrence give the name exactly as written and the bounding box of the text. Do not \
  include buildings, businesses, owners or the town name.
  Answer only with JSON: [{"text": "...", "bbox_2d": [x1, y1, x2, y2]}, ...]
  """

  # The transcription goes in "text", not "label": Qwen3.5/3.6 grounding
  # treats "label" as the category asked for and fills it with the request.
  @doc "Street/rail/water name labels with their pixel positions."
  def read_labels(image, region) do
    # OCR is the primary label source; keep the VLM's (sometimes looping) list short.
    schema = %{
      "type" => "array",
      "maxItems" => 40,
      "items" => %{
        "type" => "object",
        "properties" => %{
          "text" => %{"type" => "string"},
          "bbox_2d" => %{
            "type" => "array",
            "items" => %{"type" => "number"},
            "minItems" => 4,
            "maxItems" => 4
          }
        },
        "required" => ["text", "bbox_2d"]
      }
    }

    text = Vlm.ask(image, @labels_prompt, max_tokens: 1200, schema: schema)

    # Parse leniently: small VLMs sometimes loop until max_tokens, which
    # truncates the JSON, so pull out each complete object.
    ~r/\{[^{}]*\}/
    |> Regex.scan(text)
    |> Enum.flat_map(fn [obj] ->
      case Jason.decode(obj) do
        {:ok, %{"text" => name, "bbox_2d" => [x1, y1, x2, y2]}}
        when is_binary(name) and is_number(x1) and is_number(y1) and is_number(x2) and
               is_number(y2) ->
          {a, b} = to_px({x1, y1}, region)
          {c, d} = to_px({x2, y2}, region)
          {w, h} = {abs(c - a), abs(d - b)}
          # Sanborn street names run along their street.
          orient =
            cond do
              h > 2 * w -> :v
              w > 2 * h -> :h
              true -> nil
            end

          angle = %{h: 0.0, v: :math.pi() / 2}[orient]
          [%{name: String.trim(name), px: {(a + c) / 2, (b + d) / 2}, angle: angle}]

        _ ->
          []
      end
    end)
    |> Enum.reject(&(&1.name == "" or index_entry?(&1.name)))
    # A looping VLM repeats one name at evenly stepped boxes (Vineland 16:
    # "S. 8TH" five times); a real street is rarely labelled more than twice.
    |> Enum.group_by(& &1.name)
    |> Enum.flat_map(fn {_, ls} -> Enum.take(ls, 2) end)
    |> Enum.uniq_by(fn %{name: n, px: {x, y}} -> {n, round(x / 200), round(y / 200)} end)
  end

  # name as written -> gazetteer key
  def match_names(names, osm) do
    names
    |> Enum.map(&{&1, Osm.match_name(osm, &1)})
    |> Enum.reject(fn {_, k} -> is_nil(k) end)
    |> Enum.uniq_by(&elem(&1, 1))
  end

  def candidate_pairs(matched, osm) do
    by_key = Map.new(matched, fn {name, key} -> {key, name} end)

    osm.intersections
    |> Enum.map(& &1.keys)
    |> Enum.uniq()
    |> Enum.filter(fn {a, b} -> Map.has_key?(by_key, a) and Map.has_key?(by_key, b) end)
    |> Enum.map(fn {a, b} = keys -> %{keys: keys, names: {by_key[a], by_key[b]}} end)
  end

  # Step 2: locate intersections -------------------------------------------------

  @doc "Ask about one named pair at a time (the image prefix is cached by llama-server)."
  def locate_each(pairs, image, region) do
    Enum.flat_map(pairs, fn %{names: {a, b}} = pair ->
      prompt = """
      This is a historical fire insurance map. Streets are drawn as two parallel lines with \
      the street name written between them. Point to the centre of the intersection where \
      #{a} and #{b} meet. If they do not meet on this map, answer {"point_2d": null}.
      Answer only with JSON: {"point_2d": [x, y]}
      """

      case image
           |> Vlm.ask_json(prompt, max_tokens: 64, schema: Vlm.point_schema())
           |> parse_point() do
        {x, y} ->
          px = to_px({x, y}, region)
          [%{keys: pair.keys, label: "#{a} & #{b}", px: px, coarse_px: px, source: :vlm}]

        _ ->
          []
      end
    end)
  end

  @refine_prompt """
  This is a zoomed-in crop of a historical fire insurance map. Streets are drawn as two \
  parallel lines. Point to the centre of the street intersection or crossing that is \
  closest to the centre of this image.
  Answer only with JSON: {"point_2d": [x, y]}
  """

  # Re-ask on a crop ~12% of the sheet around the coarse point.
  def refine(%{px: {u, v}} = loc, canvas) do
    side = 0.12 * max(canvas.width, canvas.height)
    region = crop_region(canvas, {u, v}, side)
    image = fetch_image(Manifest.image_url(canvas, region, @zoom))

    case image
         |> Vlm.ask_json(@refine_prompt, max_tokens: 64, schema: Vlm.point_schema())
         |> parse_point() do
      {x, y} ->
        new = to_px({x, y}, region)
        # Refinement may only nudge; if it jumps far it picked another junction.
        if Geometry.dist(new, loc.px) < side * 0.3, do: %{loc | px: new}, else: loc

      _ ->
        loc
    end
  end

  # Step 3: mask -------------------------------------------------------------------

  @mask_prompt """
  This is a scanned map sheet. Find the printed border (neatline) that encloses the map \
  drawing, excluding the blank paper margin outside it. Give its four corners in the order \
  top-left, top-right, bottom-right, bottom-left.
  Answer only with JSON: {"corners": [[x, y], [x, y], [x, y], [x, y]]}
  """

  def neatline(canvas, overview) do
    full = [{0, 0}, {canvas.width, 0}, {canvas.width, canvas.height}, {0, canvas.height}]

    corners_schema = %{
      "type" => "object",
      "properties" => %{
        "corners" => %{
          "type" => "array",
          "minItems" => 4,
          "maxItems" => 4,
          "items" => %{
            "type" => "array",
            "items" => %{"type" => "number"},
            "minItems" => 2,
            "maxItems" => 2
          }
        }
      },
      "required" => ["corners"]
    }

    case Vlm.ask_json(overview, @mask_prompt, max_tokens: 128, schema: corners_schema) do
      {:ok, %{"corners" => [_, _, _, _] = corners}} ->
        pts =
          Enum.map(corners, fn [x, y] -> to_px({x, y}, {0, 0, canvas.width, canvas.height}) end)

        if plausible_mask?(pts, canvas), do: pts, else: full

      _ ->
        full
    end
  end

  # The neatline should cover most of the sheet; otherwise fall back to the full canvas.
  defp plausible_mask?(pts, canvas) do
    area =
      pts
      |> Enum.zip(tl(pts) ++ [hd(pts)])
      |> Enum.reduce(0, fn {{x1, y1}, {x2, y2}}, acc -> acc + x1 * y2 - x2 * y1 end)
      |> abs()
      |> Kernel./(2)

    area > 0.5 * canvas.width * canvas.height
  end

  # Helpers ----------------------------------------------------------------------

  @doc "Point from a VLM answer: {\"point_2d\": [x, y]} or [{\"point_2d\": [x, y]}, ...] (first)."
  def parse_point({:ok, json}), do: parse_point(json)
  def parse_point(%{"point_2d" => [x, y]}) when is_number(x) and is_number(y), do: {x, y}
  def parse_point([first | _]), do: parse_point(first)
  def parse_point(_), do: nil

  # A square crop centred on {u, v}, clipped to the canvas the way IIIF clips
  # regions, so pixel mapping through to_px/2 stays exact.
  def crop_region(canvas, {u, v}, side) do
    {x0, y0} =
      {min(max(u - side / 2, 0), canvas.width - 1), min(max(v - side / 2, 0), canvas.height - 1)}

    {x0, y0, max(min(side, canvas.width - x0), 1), max(min(side, canvas.height - y0), 1)}
  end

  # Qwen3-VL points are 0..1000 relative to the image it saw.
  def to_px({x, y}, {rx, ry, rw, rh}), do: {rx + x / 1000 * rw, ry + y / 1000 * rh}

  def fetch_image(url) do
    dir = Path.expand("~/.cache/dpul_georef/img")
    File.mkdir_p!(dir)
    path = Path.join(dir, Base.encode16(:crypto.hash(:md5, url)) <> ".jpg")

    if File.exists?(path) do
      File.read!(path)
    else
      %{status: 200, body: body} = Req.get!(url, decode_body: false, receive_timeout: 120_000)
      File.write!(path, body)
      body
    end
  end

  @doc """
  Where to look. The catalog bbox is a hint, not truth (Hightstown's points at
  Hamilton). Find the title's place name in OSM: if a same-named place lies in
  the padded catalog bbox use that bbox, otherwise use a box around the place.
  """
  def search_bbox(manifest) do
    meta = manifest.bbox && pad(manifest.bbox, 0.2)

    town =
      manifest.label
      |> to_string()
      |> String.replace(~r/^\s*insurance maps? of\s+/i, "")
      |> String.split([",", "[", ":"])
      |> hd()
      |> String.trim()

    places = Osm.find_place(town)
    inside = meta && Enum.find(places, fn %{lonlat: [x, y]} -> inside?(meta, x, y) end)

    cond do
      # Some catalog boxes are county-sized (Camden 45 x 61 km); a box that
      # big multiplies same-named streets, so search around the town instead.
      inside && area(meta) > 2 * area(place_box(inside)) -> place_box(inside)
      inside -> at_least_town(meta)
      places != [] -> place_box(hd(places))
      meta -> at_least_town(meta)
      true -> raise "no location for #{inspect(manifest.label)}"
    end
    |> tap(fn b ->
      Logger.info("georef: search bbox #{inspect(b)} (#{town}: #{length(places)} places)")
    end)
  end

  defp inside?({a, b, c, d}, x, y), do: x >= a and x <= c and y >= b and y <= d
  defp area({a, b, c, d}), do: (c - a) * (d - b)

  # Catalog boxes can be tighter than the atlas (Bound Brook's 4 km box clips
  # the Middlesex sheets next door): never search less than a town box.
  defp at_least_town({a, b, c, d}) do
    {x0, y0, x1, y1} = place_box([(a + c) / 2, (b + d) / 2])
    {min(a, x0), min(b, y0), max(c, x1), max(d, y1)}
  end

  # ~7 km around a town; a city atlas (Camden's shipyard sheets lie 4 km from
  # the city node) needs ~13 km.
  defp place_box(%{place: "city", lonlat: [x, y]}), do: {x - 0.08, y - 0.06, x + 0.08, y + 0.06}
  defp place_box(%{lonlat: lonlat}), do: place_box(lonlat)
  defp place_box([x, y]), do: {x - 0.04, y - 0.03, x + 0.04, y + 0.03}

  defp pad({a, b, c, d}, f) do
    {dx, dy} = {(c - a) * f, (d - b) * f}
    {a - dx, b - dy, c + dx, d + dy}
  end
end
