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

  alias DpulCollections.Georef.{
    Renames,
    Annotation,
    Consistency,
    Geometry,
    Manifest,
    Mask,
    Neighbour,
    Ocr,
    Osm,
    Parts,
    Py,
    Slide,
    Vlm
  }

  @overview 1536
  @min_label_hits 3
  # Measured on a 12-atlas sample: 0.4 declined correct fits with 4-6 of
  # 11-17 labels on their streets; at 0.25 the one wrong fit it let through
  # was caught by the printed-scale check below.
  @min_label_fraction 0.25
  # Princeton's Sanborn scans: printed scale + fitted m/px imply 392-398 dpi.
  # Fitted scale vs the canvas's 395-dpi grid (Manifest.px_scale normalises
  # scans): 111 correct fits fall in 0.925-1.055; Princeton 1918 Sheet 13
  # (campus, anchored on building names) fitted at 1.10.
  @scan_dpi {355, 427}
  @nominal_dpi 395
  @rough_candidates 8
  # Without a printed scale in the part, the fit must still imply one of
  # Sanborn's scales (sheets 50/60/100 ft, key maps 200+): Spotswood 1910 fitted
  # at half scale (0.019 m/px) with its "50 ft" printed only in the cartouche.
  @standard_scales_ft [50, 60, 100, 200, 300, 400, 500, 600, 800, 1000]
  @label_tolerance 8.0
  @key_map_ratio 4
  @key_map_hits 8
  @key_map_pad 0.1
  @scale_same_px 300
  @min_tile_name_px 78
  @rough_label_tolerance 15.0
  @scale_range {0.005, 2.0}
  @zoom 768

  def run(url, opts \\ []) do
    # no VLM server up front: by default only the slide fallback asks it,
    # and Vlm.ask/3 starts it on first use
    manifest = Manifest.fetch(url)
    bbox = search_bbox(manifest)
    osm = Osm.load(bbox)
    # The town's own name in the title cartouche ("SWEDESBORO") matches a
    # modern road named after the town (Swedesboro Road) and is not on it.
    opts = Keyword.put_new(opts, :exclude_keys, [Osm.normalize(town_name(manifest))])

    canvases =
      case Keyword.get(opts, :canvases) do
        nil -> manifest.canvases
        idx -> Enum.map(idx, &Enum.at(manifest.canvases, &1))
      end

    {results, osm, renames} =
      canvases
      |> Enum.flat_map(fn canvas ->
        Logger.info("georef: #{manifest.label} / #{canvas.label}")
        georeference_canvas(canvas, osm, opts)
      end)
      |> retry_pass(canvases, osm, opts)
      |> rename_pass(canvases, osm, opts)

    results =
      results
      |> slide_pass(manifest, osm, opts)
      |> neighbour_pass(manifest, osm, opts)
      |> rescue_pass(osm, opts)
      |> Consistency.check(&tokens_of/1)
      |> align_pass(osm, opts)

    ok = Enum.filter(results, &(&1.status == :ok))

    %{
      manifest: manifest,
      osm: osm,
      results: results,
      renames: renames,
      annotation: Annotation.page(manifest, ok)
    }
  end

  @doc "Returns one result per part of the sheet."
  def georeference_canvas(canvas, osm, opts \\ []) do
    overview = fetch_image(Manifest.image_url(canvas, "full", @overview))
    full_region = {0, 0, canvas.width, canvas.height}

    neatline = neatline(canvas, overview, opts)
    parts = Parts.split(canvas, neatline, &fetch_image/1)

    # Street-name labels and where they are printed. Labels sit on their
    # street, which gives an identity check independent of junction pointing.
    # OCR (rotated boxes, precise) is the primary label source; VLM labels
    # fill in what OCR missed.
    ocr_tokens = Ocr.read(canvas, &fetch_image/1)
    ocr_pts = ocr_labels(ocr_tokens, osm) ++ tiled_labels(canvas, ocr_tokens, osm, opts)
    # Scale statements from the tiles too (cached; tiled_labels reads them
    # anyway): Bridgeton 1915 Sheet 19's title read "SCALE I0OO FT." whole
    # and "SCALE IOOFT." tiled, against a "Scale 100 Ft." bar; a tie went
    # to the misread title (the topmost).
    scales =
      printed_scales(
        ocr_tokens ++
          if(Keyword.get(opts, :tiled_labels, true),
            do: Ocr.read_tiled(canvas, &fetch_image/1),
            else: []
          )
      )

    # `vlm_labels: false` (ablation): no VLM label reading or crossing pointing
    vlm_on = Keyword.get(opts, :vlm_labels, false)
    vlm_labels = if vlm_on, do: read_labels(overview, full_region), else: []

    vlm_matched =
      vlm_labels |> Enum.map(& &1.name) |> Enum.uniq() |> match_names(osm) |> Map.new()

    vlm_pts =
      for l <- vlm_labels,
          k = vlm_matched[l.name],
          not Enum.any?(ocr_pts, &(&1.key == k and Geometry.dist(&1.px, l.px) < 400)),
          do: l |> Map.put(:key, k) |> Map.put(:source, :vlm)

    label_pts =
      (ocr_pts ++ vlm_pts)
      |> drop_stamp_text(ocr_tokens)
      |> drop_title_town(ocr_tokens, Keyword.get(opts, :exclude_keys, []))

    matched = label_pts |> Enum.map(&{&1.name, &1.key}) |> Enum.uniq_by(&elem(&1, 1))
    pairs = candidate_pairs(matched, osm)

    # Seeds: label-line junctions (reliable identity) + VLM-located named
    # crossings (precise-ish, identity often wrong). They only propose fits.
    seeds =
      (label_junctions(label_pts, osm, canvas) ++
         if(vlm_on, do: locate_each(pairs, overview, full_region), else: []))
      |> maybe_refine(canvas, opts)

    parts
    |> Enum.with_index(1)
    |> Enum.map(fn {polygon, i} ->
      inside = &Mask.inside_polygon?(&1, polygon)
      part_labels = Enum.filter(label_pts, &inside.(&1.px))
      part_seeds = Enum.filter(seeds, &inside.(&1.px))

      label = if length(parts) > 1, do: "#{canvas.label} (part #{i})", else: canvas.label

      # Printed "Scale N Ft. to an Inch" inside this part (an inset's scale
      # often differs from the main map's, so no sheet-wide fallback). An
      # unsplit inset can put its own statement inside the part (Princeton
      # 1918 Sheet 16: 100 ft by the title and the scale bar, 50 ft on an
      # inset): the majority wins, then the one nearest the top (the title).
      printed = printed_scale(Enum.filter(scales, &inside.(&1.px)))
      # ...but a part without its own statement still tries the sheet's stated
      # scales in its search (Avon 1905 Sheet 64 inset: 60 ft, stated only in
      # the main part)
      part_opts = Keyword.put(opts, :sheet_scales, scales |> Enum.map(& &1.ft) |> Enum.uniq())

      %{
        canvas: canvas,
        part: i,
        label: label,
        mask: polygon,
        labels: part_labels,
        printed_scale_ft: printed
      }
      |> Map.merge(fit_part(canvas, osm, polygon, part_labels, part_seeds, printed, part_opts))
      |> key_map_mask(osm)
    end)
  end

  defp fit_part(canvas, osm, polygon, label_pts, seeds, printed_ft, opts) do
    seed_candidates = to_candidates(seeds, osm)

    roughs =
      best_hypotheses(
        seed_candidates,
        label_pts,
        osm,
        printed_ft,
        Keyword.get(opts, :sheet_scales, [])
      )

    rough = List.first(roughs)

    Logger.debug(fn ->
      "georef: rough candidates " <>
        Enum.map_join(
          roughs,
          " ",
          &"#{&1.label_hits}/#{&1.seed_inliers}@#{Float.round(Geometry.scale(&1.t), 4)}"
        )
    end)

    needed = needed_hits(length(label_pts), opts)

    # Labels first: printed names sit on street centrelines, so snapping them
    # onto their modern streets is more precise than VLM junction pinpoints
    # (which lean ~7 m toward a street edge). On the check-point maps:
    # median 1.9 m vs 2.5 m, and no zoomed VLM calls needed.
    # The top rough fits are each refined and the one putting the most labels
    # on their streets wins: ICP from a slightly-off rough fit can settle in a
    # worse optimum that still passes the gates (Hightstown 1916 Sheet 3 when
    # one extra label changed which rough fit ranked first).
    labels_fit =
      if Keyword.get(opts, :labels_first, true) do
        # Each start is refined with all labels and without the tile-only ones
        # (a wrong extra label can hold ICP in a worse optimum); hits are
        # always counted on all labels.
        base = Enum.reject(label_pts, & &1[:tiled])
        subsets = Enum.uniq([label_pts, base])

        fits =
          for r <- roughs,
              t <- Enum.uniq([r.t, r.t0, snap_scale(r.t, label_pts, printed_ft)]),
              ls <- subsets do
            {r, labels_only_fit(t, label_pts, osm, polygon, needed, printed_ft, ls)}
          end
          |> Enum.filter(&elem(&1, 1))

        # Junction seeds count too (half a label each): a start can drift in
        # ICP to a rotated fit that puts one more label on a street but leaves
        # the seeds behind (Bay Head 1905 Sheet 48: 6 labels at -35 deg vs 5
        # labels and 6 seeds at -10 deg).
        score = fn f ->
          weighted_hits(f.transform, label_pts, osm) +
            0.5 * length(Geometry.inliers_of(f.transform, seed_candidates, 30.0))
        end

        case Enum.max_by(fits, fn {_, f} -> score.(f) end, fn -> nil end) do
          nil -> nil
          {r, best} -> {r, Map.put(best, :rival_hits, rival_hits(best, fits, polygon))}
        end
      end

    if labels_fit do
      {r, fit} = labels_fit

      if r != rough,
        do:
          Logger.info(
            "georef: rough fit ##{Enum.find_index(roughs, &(&1 == r)) + 1} refined best (#{fit.label_hits} labels)"
          )

      Map.merge(%{located: seeds, rough: Map.drop(r, [:t, :t0])}, fit)
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

  # Canvases with a declined part are run again with a bigger VLM (which reads
  # more street names but is ~2.5x slower); the retry's parts replace the
  # originals only when more of them fit. Runs before the slide pass so the
  # slide sees the retry's fits as neighbours.
  defp retry_pass(results, canvases, osm, opts) do
    model = Keyword.get(opts, :retry_model)
    by_canvas = Enum.group_by(results, & &1.canvas.id)

    failing =
      Enum.filter(canvases, fn c -> Enum.any?(by_canvas[c.id] || [], &(&1.status != :ok)) end)

    if model && failing != [] do
      retried =
        Vlm.with_model(model, fn ->
          Map.new(failing, fn c ->
            Logger.info("georef: retrying #{c.label} with #{model}")
            {c.id, georeference_canvas(c, osm, opts)}
          end)
        end)

      Enum.flat_map(canvases, fn c ->
        old = by_canvas[c.id] || []
        new = retried[c.id]

        if new && fitted_count(new) > fitted_count(old),
          do: Enum.map(new, &Map.put(&1, :model, model)),
          else: old
      end)
    else
      results
    end
  end

  # Street renames learned from the fitted sheets (Georef.Renames): canvases
  # with a declined part are run again with the renamed streets as aliases;
  # their parts replace the originals only when more of them fit.
  # Corridor rescue (image evidence for near misses): a declined part whose
  # junction seeds give a start putting >= 3 labels near their streets (one
  # short of a single-seed fit) is aligned to the printed street corridors
  # from each such start; it is accepted when exactly one distinct start ends
  # with >= 3 labels on their streets, a scale consistent with the print and
  # corridor contrast >= #{0.1} (modern centrelines run in the printed streets
  # there and not at nearby placements). Berlin 1929 Sheet 6, Cranbury 1916
  # Sheet 2, Manasquan 1921 Sheet 87, Princeton 1911 Sheet 18 part 3.
  @rescue_contrast 0.1
  @align_px 3000
  @rescue_starts 5

  defp rescue_pass(results, osm, opts) do
    if Keyword.get(opts, :rescue, true) do
      exclude = Keyword.get(opts, :exclude_keys, [])
      atlas_ft = atlas_scale_ft(results)

      Enum.map(results, fn r ->
        r |> corridor_rescue(osm, exclude) |> seed_rescue(osm, exclude, atlas_ft)
      end)
    else
      results
    end
  end

  # Seed placement (priv/georef/seedplace.py): a part still declined that has
  # a junction seed is placed from the seed and the labels of its two streets
  # alone: rotation swept, aligned to the printed street corridors, accepted
  # only with a clear contrast peak whose labels run along their streets and
  # no symmetric rival. Leave-one-out on 127 fitted parts: 65 placed, 0 wrong.
  @seed_max 4

  defp seed_rescue(%{status: :failed} = r, osm, exclude, atlas_ft) do
    labels = Enum.reject(r.labels, &(&1.key in exclude))
    seeds = r[:located] |> List.wrap() |> to_candidates(osm) |> Enum.take(@seed_max)
    ft = r.printed_scale_ft || atlas_ft

    if seeds == [] or ft == nil do
      r
    else
      jpg = fetch_image(Manifest.image_url(r.canvas, "full", @align_px))

      input = %{
        width: r.canvas.width,
        mask: Enum.map(r.mask, &Tuple.to_list/1),
        seeds:
          for(
            s <- seeds,
            do: %{px: Tuple.to_list(s.px), xy: Tuple.to_list(s.xy), keys: Tuple.to_list(s.key)}
          ),
        scales: [ft * 0.3048 / @nominal_dpi],
        labels:
          for(
            l <- labels,
            do: %{
              key: l.key,
              px: Tuple.to_list(l.px),
              angle: if(l[:source] == :ocr, do: l[:angle])
            }
          )
      }

      case Py.run("seedplace.py", input, jpg, osm, exclude, ["scipy"]) do
        %{"t" => t, "contrast" => k} when is_map(t) ->
          t = Map.new(t, fn {key, v} -> {String.to_existing_atom(key), v} end)
          hits = label_score(t, labels, osm)

          Logger.info(
            "georef: #{r.label} placed from a junction seed (contrast #{Float.round(k, 2)}, #{hits} labels on their streets)"
          )

          r
          |> Map.merge(fit_result(t, labels, osm, r.mask, hits))
          |> Map.put(:method, :seed_placement)

        %{"why" => why} ->
          Logger.info("georef: #{r.label} not placed from seeds: #{why}")
          r
      end
    end
  rescue
    e ->
      Logger.warning("georef: #{r.label} seed placement skipped: #{Exception.message(e)}")
      r
  end

  defp seed_rescue(r, _osm, _exclude, _atlas_ft), do: r

  # the atlas's usual scale class (ft to the inch) among its fitted parts
  defp atlas_scale_ft(results) do
    fts =
      for %{status: :ok, transform: t} <- results do
        ft = Geometry.scale(t) * @nominal_dpi / 0.3048
        Enum.min_by([50, 60, 100, 200, 400], &abs(:math.log(ft / &1)))
      end

    if fts == [], do: nil, else: fts |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0)
  end

  defp corridor_rescue(%{status: :failed} = r, osm, exclude) do
    labels = Enum.reject(r.labels, &(&1.key in exclude))
    seeds = to_candidates(r[:located] || [], osm)
    c = centroid(r.mask)

    starts =
      seeds
      |> single_seed_hypotheses(r.printed_scale_ft, [])
      |> Enum.map(fn {t, _} -> {label_score(t, labels, osm, rough_tolerance(t)), t} end)
      |> Enum.filter(&(elem(&1, 0) >= @min_label_hits))
      |> Enum.sort_by(&(-elem(&1, 0)))
      |> Enum.reduce([], fn {_, t}, kept ->
        if length(kept) >= @rescue_starts or
             Enum.any?(
               kept,
               &(Geometry.dist(Geometry.transform(&1, c), Geometry.transform(t, c)) < 40)
             ),
           do: kept,
           else: kept ++ [t]
      end)

    if starts == [] do
      r
    else
      jpg = fetch_image(Manifest.image_url(r.canvas, "full", @align_px))

      input = %{
        width: r.canvas.width,
        mask: Enum.map(r.mask, &Tuple.to_list/1),
        candidates: Enum.map(starts, &Map.take(&1, [:a, :b, :tx, :ty])),
        labels: for(l <- labels, do: %{key: l.key, px: Tuple.to_list(l.px)})
      }

      %{"candidates" => out} = Py.run("align.py", input, jpg, osm, exclude, ["scipy"])

      passing =
        for %{"t" => t, "contrast" => k} <- out,
            t = Map.new(t, fn {key, v} -> {String.to_existing_atom(key), v} end),
            hits = label_score(t, labels, osm),
            k >= @rescue_contrast and hits >= @min_label_hits and
              scale_consistent?(Geometry.scale(t), r.printed_scale_ft),
            do: {t, hits, k}

      distinct =
        Enum.uniq_by(passing, fn {t, _, _} ->
          {x, y} = Geometry.transform(t, c)
          {round(x / 40), round(y / 40)}
        end)

      case distinct do
        [{t, hits, k}] ->
          Logger.info(
            "georef: #{r.label} rescued by street corridors (#{hits} labels on their streets, contrast #{Float.round(k, 2)})"
          )

          r
          |> Map.merge(fit_result(t, labels, osm, r.mask, hits))
          |> Map.put(:method, :corridor_rescue)

        _ ->
          Logger.info(
            "georef: #{r.label} not rescued: " <>
              Enum.map_join(out, "; ", fn %{"t" => t, "contrast" => k} ->
                t = Map.new(t, fn {key, v} -> {String.to_existing_atom(key), v} end)

                "#{label_score(t, labels, osm)} labels, contrast #{Float.round(k, 2)}, " <>
                  "#{round(Geometry.scale(t) * @nominal_dpi / 0.3048)} ft"
              end)
          )

          r
      end
    end
  rescue
    e ->
      Logger.warning("georef: #{r.label} corridor rescue skipped: #{Exception.message(e)}")
      r
  end

  defp corridor_rescue(r, _osm, _exclude), do: r

  # Last: every accepted fit is aligned to the printed street corridors
  # (priv/georef/align.py, image comparison). Kept only if no label leaves its
  # street; the script itself refuses moves over 15 m or 3 degrees.
  defp align_pass(results, osm, opts) do
    if Keyword.get(opts, :align, true) do
      exclude = Keyword.get(opts, :exclude_keys, [])
      Enum.map(results, &align(&1, osm, exclude))
    else
      results
    end
  end

  defp align(%{status: :ok} = r, osm, exclude) do
    jpg = fetch_image(Manifest.image_url(r.canvas, "full", @align_px))

    input = %{
      width: r.canvas.width,
      mask: Enum.map(r.mask, &Tuple.to_list/1),
      t: Map.take(r.transform, [:a, :b, :tx, :ty]),
      labels: for(l <- r.labels, l.key not in exclude, do: %{key: l.key, px: Tuple.to_list(l.px)})
    }

    case Py.run("align.py", input, jpg, osm, exclude, ["scipy"]) do
      %{"t" => %{} = t} = out ->
        t = Map.new(t, fn {k, v} -> {String.to_existing_atom(k), v} end)
        hits = label_score(t, r.labels, osm)

        # a wide-start alignment (a fit stuck a few degrees off) may lose one
        # label: it was held on its street by the wrong rotation (Bay Head 51)
        slack = if out["wide"], do: 1, else: 0

        if hits >= label_score(r.transform, r.labels, osm) - slack do
          Logger.info(
            "georef: #{r.label} aligned to street corridors: moved #{Float.round(out["move_m"], 1)} m, " <>
              "#{Float.round(out["drot_deg"], 2)} deg (#{out["n"]} corridor samples)" <>
              if(out["wide"],
                do:
                  ", from a wider rotation start (contrast #{Float.round(out["contrast0"], 2)} -> #{Float.round(out["contrast"], 2)})",
                else: ""
              )
          )

          gcps =
            Enum.map(r.gcps, fn g ->
              %{g | lonlat: Geometry.to_lonlat(osm.projection, Geometry.transform(t, g.px))}
            end)

          %{r | transform: t, gcps: gcps, scale: Geometry.scale(t)}
          |> Map.put(:aligned, %{
            move_m: out["move_m"],
            drot_deg: out["drot_deg"],
            n: out["n"],
            wide: out["wide"]
          })
        else
          r
        end

      _ ->
        r
    end
  rescue
    e ->
      Logger.warning("georef: #{r.label} corridor alignment skipped: #{Exception.message(e)}")
      r
  end

  defp align(r, _osm, _exclude), do: r

  defp rename_pass(results, canvases, osm, opts) do
    by_canvas = Enum.group_by(results, & &1.canvas.id)

    failing =
      Enum.filter(canvases, fn c -> Enum.any?(by_canvas[c.id] || [], &(&1.status != :ok)) end)

    # Votes are gathered on every atlas (they are kept in the report as
    # data: which printed names sit on which modern streets).
    votes =
      if Keyword.get(opts, :renames, true) do
        exclude = Keyword.get(opts, :exclude_keys, [])

        results
        |> Enum.filter(&(&1.status == :ok))
        |> Enum.flat_map(&Renames.observe(&1, tokens_of(&1.canvas), osm, exclude))
      else
        []
      end

    table = Renames.table(votes)
    info = %{table: table, votes: Renames.vote_counts(votes)}

    if table == %{} or failing == [] do
      {results, osm, info}
    else
      Logger.info("georef: learned street renames #{inspect(table)}")
      aliased = Osm.with_aliases(osm, table)

      canvases
      |> Enum.flat_map(fn c ->
        old = by_canvas[c.id] || []

        if c in failing do
          new = georeference_canvas(c, aliased, opts)

          if fitted_count(new) > fitted_count(old),
            do: Enum.map(new, &Map.put(&1, :renames, table)),
            else: old
        else
          old
        end
      end)
      |> then(&{&1, aliased, info})
    end
  end

  defp fitted_count(parts), do: Enum.count(parts, &(&1.status == :ok))

  defp needed_hits(n_labels, opts) do
    fraction = Keyword.get(opts, :min_label_fraction, @min_label_fraction)
    max(@min_label_hits, ceil(fraction * n_labels))
  end

  # Second pass, after every canvas: declined parts whose labels name only
  # parallel streets get the slide fallback (see Georef.Slide). Its confirmed
  # cross-street reads become extra labels and the normal labels-only fit and
  # gates decide. Without a printed scale the slide searches the scale class
  # of the neighbouring fitted sheets (Slide.scales_ft/3), so it runs after
  # the normal pass; rescues with a printed scale go first and count as fitted.
  defp slide_pass(results, manifest, osm, opts) do
    if Keyword.get(opts, :slide, true) do
      Process.put(:slide_vlm, Keyword.get(opts, :slide_vlm, false))
      index = manifest.canvases |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, i} end)
      exclude = [Osm.normalize(town_name(manifest))]
      fitted = for r <- results, r.status == :ok, do: {index[r.canvas.id], r.scale}

      eligible =
        results
        |> Enum.with_index()
        |> Enum.filter(fn {r, _} -> Slide.eligible?(r, exclude) end)
        |> Enum.sort_by(fn {r, _} -> is_nil(r.printed_scale_ft) end)

      {rescued, _} =
        Enum.map_reduce(eligible, fitted, fn {r, i}, fitted ->
          scales = Slide.scales_ft(r.printed_scale_ft, fitted, index[r.canvas.id])
          r = slide_fit(r, osm, scales, exclude, opts)

          fitted =
            if r.status == :ok and r.printed_scale_ft,
              do: [{index[r.canvas.id], r.scale} | fitted],
              else: fitted

          {{i, r}, fitted}
        end)

      Enum.reduce(rescued, results, fn {i, r}, acc -> List.replace_at(acc, i, r) end)
    else
      results
    end
  end

  defp slide_fit(r, osm, scales_ft, exclude, opts) do
    with %{t: t, labels: extra} <- Slide.confirm(r, osm, scales_ft, exclude, &fetch_image/1),
         labels = r.labels ++ extra,
         needed = needed_hits(length(labels), opts),
         %{} = fit <- labels_only_fit(t, labels, osm, r.mask, needed, r.printed_scale_ft) do
      Logger.info(
        "georef: #{r.label} fitted by slide (read #{inspect(Enum.map(extra, & &1.key))}, #{fit.label_hits}/#{needed} labels on their streets)"
      )

      r |> Map.merge(fit) |> Map.merge(%{labels: labels, method: :slide})
    else
      _ ->
        Logger.info("georef: #{r.label} slide fallback found no confirmed placement")
        r
    end
  end

  @doc """
  Third pass (after the slide, before `Consistency.check/2` so a bad placement
  can still be caught): declined parts that name at least two modern streets
  are placed from the fitted sheets around them (see Georef.Neighbour). Public
  so the post-passes can be replayed on a saved report.
  """
  def neighbour_pass(results, manifest, osm, opts \\ []) do
    exclude = [Osm.normalize(town_name(manifest))]
    eligible? = &Neighbour.eligible?(&1, osm, exclude)

    if Keyword.get(opts, :neighbour, true) and Enum.any?(results, eligible?) do
      ctx = Neighbour.context(results, manifest, osm, exclude, &tokens_of/1)
      Enum.map(results, &if(eligible?.(&1), do: neighbour_fit(&1, ctx), else: &1))
    else
      results
    end
  end

  defp neighbour_fit(r, ctx) do
    case Neighbour.place(r, ctx, &fetch_image/1) do
      %{t: t, labels: extra, hits: hits} ->
        labels = r.labels ++ extra

        Logger.info(
          "georef: #{r.label} fitted by neighbour placement (read #{inspect(Enum.map(extra, & &1.key))}, #{hits}/#{length(labels)} labels on their streets)"
        )

        r
        |> Map.merge(fit_result(t, labels, ctx.osm, r.mask, hits))
        |> Map.merge(%{labels: labels, method: :neighbour})

      nil ->
        Logger.info("georef: #{r.label} neighbour placement found no confirmed placement")
        r
    end
  end

  defp tokens_of(canvas), do: Ocr.read(canvas, &fetch_image/1)

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
    # `vlm_points: false` (ablation): no zoomed VLM pinpointing
    verified =
      if rough && Keyword.get(opts, :vlm_points, false),
        do: verify_predictions(rough.t, osm, canvas, polygon),
        else: []

    candidates = seed_candidates ++ Enum.map(verified, &Map.put(&1, :key, &1.keys))
    base = %{located: seeds ++ verified, rough: rough && Map.drop(rough, [:t, :t0])}

    final =
      rough &&
        Geometry.ransac(candidates,
          threshold: Keyword.get(opts, :threshold, 10.0),
          scale_range: @scale_range,
          # label-line junctions are ~2x more accurate than VLM pinpoints
          weight: fn c -> if c[:source] == :labels, do: 3, else: 1 end
        )

    label_check = with {:ok, t, _, _} <- final, do: label_score(t, label_pts, osm)

    scale_ok =
      with {:ok, t, _, _} <- final,
           do: scale_ok?(Geometry.scale(t), printed_ft, label_check)

    case final do
      {:ok, t0, inliers, residuals}
      when length(inliers) >= 3 and label_check >= needed and scale_ok ->
        # Labels sit on street centrelines (~1-3 m) — more precise than VLM
        # junction pinpoints (measured ~7 m, often on a street edge) — so let
        # them refine the fit, anchored by label-line junctions when there are
        # enough. GCPs go at the observed junction pixels with world coords
        # from that fit.
        curves = for l <- label_pts, g = osm.groups[l.key], do: {l.px, g.segments, g[:polygons]}
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
  defp labels_only_fit(t0, label_pts, osm, polygon, needed, printed_ft, icp_labels \\ nil) do
    curves =
      for l <- icp_labels || label_pts,
          g = osm.groups[l.key],
          do: {l.px, g.segments, g[:polygons]}

    direct = Geometry.refine_with_curves(t0, [], curves, tolerance: @label_tolerance)

    # A rough fit is only good to ~15 m: at 8 m from the start too few labels
    # may pair and ICP drifts (Westville 1909 Sheet 1 part 2: rough fit 5
    # labels on their streets, refined 1, after losing one LAKE read). Also
    # try tightening in steps; the start putting more labels on streets wins.
    stepped =
      Enum.reduce([20.0, 12.0, @label_tolerance], t0, fn tol, t ->
        Geometry.refine_with_curves(t, [], curves, tolerance: tol)
      end)

    # The stepped start only rescues a direct fit that fails the gates: as an
    # equal alternative it found a 9-degree-off optimum on Washington 1884
    # Sheet 1 (two real street labels; small CORNISH / Shea notes made the
    # rotated fit score one more hit).
    direct_hits = label_score(direct, label_pts, osm)

    direct_ok =
      direct_hits >= needed and crossing_streets?(direct, label_pts, osm) and
        scale_ok?(Geometry.scale(direct), printed_ft, direct_hits)

    {t, hits} =
      if direct_ok,
        do: {direct, direct_hits},
        else: {stepped, label_score(stepped, label_pts, osm)}

    crossing = hits >= needed and crossing_streets?(t, label_pts, osm)
    scale_ok = scale_ok?(Geometry.scale(t), printed_ft, hits)

    if hits >= needed and not (crossing and scale_ok) do
      Logger.debug(
        "georef: labels-only fit rejected: #{hits} hits, crossing=#{crossing}, " <>
          "scale #{Float.round(Geometry.scale(t), 4)} m/px (printed #{inspect(printed_ft)}) ok=#{scale_ok}"
      )
    end

    if hits >= needed and crossing and scale_ok,
      do: fit_result(t, label_pts, osm, polygon, hits)
  end

  # An accepted fit without junctions: GCPs are the part outline and the
  # labels, mapped through the fit.
  # Choosing among candidate fits, small lettering counts less: of the labels
  # under 80 px in accepted fits most were notes, key or business text
  # (GREEN, GARAGE, CORNISH), against street names at 105-170 px; on
  # Washington 1884 Sheet 1 two such notes outvoted a correct fit. Named
  # buildings are lettered small by nature and count fully.
  defp weighted_hits(t, label_pts, osm) do
    label_pts
    |> Enum.filter(
      &(Osm.distance_to(osm, &1.key, Geometry.transform(t, &1.px)) <= @label_tolerance)
    )
    |> Enum.map(fn l ->
      h = l[:height]

      cond do
        match?(%{kind: :building}, osm.groups[l.key]) -> 1.0
        is_nil(h) or h >= 90 -> 1.0
        h >= 80 -> 0.75
        true -> 0.5
      end
    end)
    |> Enum.sum()
  end

  # Most labels on streets among passing fits substantially different from
  # the best (part centre > 15 m apart or > 2 degrees of rotation): a rival
  # nearly as good means the labels do not decide the placement.
  defp rival_hits(best, fits, polygon) do
    c = centroid(polygon)
    rot = fn t -> :math.atan2(t.b, t.a) * 180 / :math.pi() end

    fits
    |> Enum.map(&elem(&1, 1))
    |> Enum.filter(fn f ->
      Geometry.dist(Geometry.transform(f.transform, c), Geometry.transform(best.transform, c)) >
        15 or
        abs(rot.(f.transform) - rot.(best.transform)) > 2
    end)
    |> Enum.map(& &1.label_hits)
    |> Enum.max(fn -> nil end)
  end

  defp fit_result(t, label_pts, osm, polygon, hits) do
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

    # a named building on its footprint fixes position in both directions
    buildings =
      Enum.count(label_pts, fn l ->
        match?(%{kind: :building}, osm.groups[l.key]) and
          Osm.distance_to(osm, l.key, Geometry.transform(t, l.px)) <= @label_tolerance
      end)

    buildings >= 2 or (buildings >= 1 and dirs != []) or
      Enum.any?(for a <- dirs, b <- dirs, do: angle_between(a, b) > 30)
  end

  @doc """
  A part fitted as a key map under a sheet-scale statement (`scale_ok?/3`'s
  exception) is often a sheet with the key map as an inset in one corner
  (Bay Head 1905 Sheet 47: key map at the top, a 60 ft sheet below, one part).
  Its mask shrinks to the box around the labels on their streets, padded by
  #{@key_map_pad} of the part's size and kept within the part's box.
  """
  def key_map_mask(%{status: :ok, transform: t, printed_scale_ft: ft} = r, osm)
      when is_number(ft) do
    if scale_consistent?(Geometry.scale(t), ft) do
      r
    else
      hit =
        for l <- r.labels,
            Osm.distance_to(osm, l.key, Geometry.transform(t, l.px)) <= @label_tolerance,
            do: l.px

      {xs, ys} = Enum.unzip(r.mask)
      {x0, x1, y0, y1} = {Enum.min(xs), Enum.max(xs), Enum.min(ys), Enum.max(ys)}
      {hx, hy} = Enum.unzip(hit)
      {px, py} = {@key_map_pad * (x1 - x0), @key_map_pad * (y1 - y0)}
      {a, b} = {max(x0, Enum.min(hx) - px), min(x1, Enum.max(hx) + px)}
      {c, d} = {max(y0, Enum.min(hy) - py), min(y1, Enum.max(hy) + py)}
      Logger.info("georef: #{r.label} fitted as a key map; mask cut to its labels' box")
      %{r | mask: [{a, c}, {b, c}, {b, d}, {a, d}]}
    end
  end

  def key_map_mask(r, _osm), do: r

  @doc """
  The scale gate. A key map (the atlas overview, 500-1000 ft to the inch) is
  often on a canvas whose only printed statement is the sheets' scale
  (Englewood 1908 Index: "SCALE 50 FT. TO AN INCH" by the key map at 800 ft;
  Riverton, Salem, Somerville, Belmar overviews alike): a fit at a standard
  scale >= #{@key_map_ratio}x the printed one passes with >= #{@key_map_hits}
  labels on their streets.
  """
  def scale_ok?(m_per_px, printed_ft, hits) do
    scale_consistent?(m_per_px, printed_ft) or
      (is_number(printed_ft) and is_number(hits) and hits >= @key_map_hits and
         m_per_px * @nominal_dpi / 0.3048 >= @key_map_ratio * printed_ft and
         scale_consistent?(m_per_px, nil))
  end

  @doc """
  Does a fit's m/px agree with the part's printed "N ft to an inch" at the
  scan resolution? A wrong fit that still puts a few labels on same-named
  streets is usually off in scale. With no printed scale the fit must imply
  one of Sanborn's standard scales.
  """
  # a degenerate fit (every point on one spot) has no scale
  def scale_consistent?(m_per_px, _) when m_per_px <= 1.0e-6, do: false

  def scale_consistent?(m_per_px, nil),
    do: Enum.any?(@standard_scales_ft, &scale_consistent?(m_per_px, &1))

  def scale_consistent?(m_per_px, ft) do
    {lo, hi} = @scan_dpi
    dpi = ft * 0.3048 / m_per_px
    dpi >= lo and dpi <= hi
  end

  # Label and seed slop is a fixed distance on paper, so the rough tolerance
  # grows with the map scale: 15 m at 50 ft to the inch (~1 inch), up to 45 m
  # (Princeton 1911 Sheet 20, 200 ft: its one junction seed sits 18 m off).
  # Acceptance still uses @label_tolerance after refinement.
  defp rough_tolerance(t) do
    ft = Geometry.scale(t) * @nominal_dpi / 0.3048
    min(max(@rough_label_tolerance, @rough_label_tolerance * ft / 50), 3 * @rough_label_tolerance)
  end

  @doc """
  Choose a rough fit among every 2-point similarity the seeds imply. Score =
  printed labels that land on their own modern street + seed inliers. A fit
  must put at least #{@min_label_hits} labels on their streets to be trusted.
  """
  def best_hypotheses(seed_candidates, label_pts, osm, printed_ft \\ nil, sheet_ft \\ []) do
    pairs =
      seed_candidates
      |> Geometry.hypotheses(scale_range: @scale_range, min_px_separation: 300)
      |> Enum.map(&{&1, 2})

    (pairs ++ single_seed_hypotheses(seed_candidates, printed_ft, sheet_ft))
    |> Enum.map(fn {t, min_seeds} ->
      seeds = Geometry.inliers_of(t, seed_candidates, 30.0)

      %{
        t: t,
        # A 2-junction rough fit is only approximate, so count labels near
        # their street loosely here; acceptance re-checks at @label_tolerance
        # after refinement.
        label_hits: label_score(t, label_pts, osm, rough_tolerance(t)),
        seed_inliers: length(seeds),
        seeds: seeds,
        # one-seed hypotheses (below) need one more label on its street
        min_hits: if(min_seeds == 1, do: @min_label_hits + 1, else: @min_label_hits),
        min_seeds: min_seeds
      }
    end)
    |> Enum.filter(&(&1.label_hits >= &1.min_hits and &1.seed_inliers >= &1.min_seeds))
    |> Enum.map(&Map.drop(&1, [:min_hits, :min_seeds]))
    |> Enum.sort_by(&{&1.label_hits + &1.seed_inliers, &1.seed_inliers}, :desc)
    |> distinct_hypotheses(label_pts, @rough_candidates)
    |> Enum.map(fn h ->
      # refit on the hypothesis' seed inliers
      # (a seed just inside 30 m can skew the refit, so the raw 2-point fit
      # is kept as an alternative start for refinement)
      t = Geometry.fit_similarity(Enum.map(h.seeds, &{&1.px, &1.xy})) || h.t
      %{h | t: t} |> Map.delete(:seeds) |> Map.put(:t0, h.t)
    end)
  end

  # The rough fit rescaled (about the labels' centroid) to the printed scale,
  # or the nearest standard Sanborn scale, at the nominal scan resolution:
  # junction seeds are only good to 6-25 m, and a rough fit 7 % off in scale
  # refined into a worse optimum (Hightstown 1916 Sheet 3).
  # a degenerate rough fit (scale 0) has nothing to snap (Rahway 1891 Sheet 8,
  # Westville 1909 crashed on log(0))
  defp snap_scale(t, label_pts, printed_ft) do
    if Geometry.scale(t) > 1.0e-6, do: do_snap_scale(t, label_pts, printed_ft), else: t
  end

  defp do_snap_scale(t, label_pts, printed_ft) do
    s = Geometry.scale(t)

    target =
      ((printed_ft && [printed_ft]) || @standard_scales_ft)
      |> Enum.map(&(&1 * 0.3048 / @nominal_dpi))
      |> Enum.min_by(&abs(:math.log(&1 / s)))

    k = target / s
    c = centroid(Enum.map(label_pts, & &1.px))
    {x, y} = Geometry.transform(t, c)
    t2 = %{t | a: t.a * k, b: t.b * k}
    {x2, y2} = Geometry.transform(t2, c)
    %{t2 | tx: t2.tx + x - x2, ty: t2.ty + y - y2}
  end

  @doc "The best rough fit (see `best_hypotheses/4`), or nil."
  def best_hypothesis(seed_candidates, label_pts, osm, printed_ft \\ nil) do
    case best_hypotheses(seed_candidates, label_pts, osm, printed_ft) do
      [best | _] ->
        Logger.info(
          "georef: rough fit labels=#{best.label_hits} seeds=#{best.seed_inliers} scale=#{Float.round(Geometry.scale(best.t), 4)}"
        )

        best

      [] ->
        nil
    end
  end

  # Keep the top `n` hypotheses that place the labels' centroid > 10 m apart
  # (the one-seed sweep yields runs of near-identical neighbours).
  defp distinct_hypotheses(hyps, label_pts, n) do
    c = centroid(Enum.map(label_pts, & &1.px))

    Enum.reduce_while(hyps, [], fn h, kept ->
      cond do
        length(kept) >= n ->
          {:halt, kept}

        Enum.any?(
          kept,
          &(Geometry.dist(Geometry.transform(&1.t, c), Geometry.transform(h.t, c)) < 30)
        ) ->
          {:cont, kept}

        true ->
          {:cont, kept ++ [h]}
      end
    end)
  end

  defp centroid([]), do: {0.0, 0.0}

  defp centroid(pts) do
    {sx, sy} = Enum.reduce(pts, {0, 0}, fn {x, y}, {ax, ay} -> {ax + x, ay + y} end)
    {sx / length(pts), sy / length(pts)}
  end

  # With a printed scale the m/px is known (scan ~395 dpi), so one junction
  # seed fixes the fit up to rotation: sweep it in 2 degree steps and let the
  # labels decide. Renamed streets often leave a sheet with only one correct
  # seed (Branchville 1920 Sheet 1: Broad & Wantage). Without a readable
  # printed scale, sweep at the two common town-sheet scales: a sheet whose
  # named streets all meet at one junction gives no second seed (Spotswood
  # 1910: Vliet / De Voe x Main, scale printed only inside the cartouche).
  # (and at any scale stated elsewhere on the sheet).
  defp single_seed_hypotheses(seed_candidates, nil, sheet_ft),
    do:
      Enum.flat_map(
        Enum.uniq(sheet_ft ++ [50, 100]),
        &single_seed_hypotheses(seed_candidates, &1, [])
      )

  defp single_seed_hypotheses(seed_candidates, ft, _sheet_ft) do
    s = ft * 0.3048 / @nominal_dpi

    for c <- seed_candidates, deg <- 0..358//2 do
      th = deg * :math.pi() / 180
      {a, b} = {s * :math.cos(th), s * :math.sin(th)}
      {u, v} = c.px
      {x, y} = c.xy
      {%{a: a, b: b, tx: x - (a * u + b * v), ty: y - (b * u - a * v)}, 1}
    end
  end

  @doc false
  def printed_scale([]), do: nil

  # One vote per statement: whole-sheet and tiled OCR (and overlapping tiles)
  # read the same statement more than once, not always alike (Summit 1921
  # Sheet 33: "50" and "5O" from two tiles outvoted the title's 200).
  # Readings within @scale_same_px are one statement, which backs every
  # value read there (Bridgeton 1915 Sheet 19's title: "I0OO" and "IOO").
  def printed_scale(scales) do
    statements =
      Enum.reduce(scales, [], fn s, acc ->
        case Enum.split_with(acc, fn st ->
               Enum.any?(st, &(Geometry.dist(&1.px, s.px) < @scale_same_px))
             end) do
          {[], rest} -> [[s] | rest]
          {near, rest} -> [[s | List.flatten(near)] | rest]
        end
      end)

    statements
    |> Enum.flat_map(fn st ->
      top = st |> Enum.map(&elem(&1.px, 1)) |> Enum.min()
      st |> Enum.map(& &1.ft) |> Enum.uniq() |> Enum.map(&{&1, top})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.max_by(fn {_ft, tops} -> {length(tops), -Enum.min(tops)} end)
    |> elem(0)
  end

  @doc """
  Printed scale statements ("SCALE 100FT. TO AN INCH") as feet per inch. OCR
  confuses I/l with 1 and O with 0 in these, so digits are normalised.
  """
  def printed_scales(tokens) do
    for t <- tokens,
        [_, digits] <- [Regex.run(~r/s?cale[\s,.:;]*([0-9IOloZz]{2,4})\s*f/i, t.text)],
        {ft, ""} <- [
          digits
          |> String.replace(~r/[Il]/, "1")
          |> String.replace(~r/[Oo]/, "0")
          |> String.replace(~r/[Zz]/, "2")
          |> Integer.parse()
        ],
        do: %{ft: ft, px: t.center}
  end

  @doc """
  Drop labels read off a library ownership stamp ("MAP DIVISION / PRINCETON
  UNIVERSITY LIBRARY", "Library of Congress"): Branchville's "DIVISION"
  matched a modern Division Street.
  """
  def drop_stamp_text(labels, tokens) do
    stamps =
      for t <- tokens,
          Regex.match?(~r/princeton|universit|librar|congress/i, t.text),
          do: t.center

    Enum.reject(labels, fn l -> Enum.any?(stamps, &(Geometry.dist(&1, l.px) < 500)) end)
  end

  @min_street_name_px 100

  @doc """
  Drop the town's own name where it is title lettering (the cartouche or the
  sheet's header oval: next to a year, "N.J.", "Sanborn", "Population",
  "Water Facilities", "Scale"). "SWEDESBORO" there matched Swedesboro Road;
  "ELMER" printed along Elmer's street of that name is kept.
  """
  def drop_title_town(labels, tokens, town_keys) do
    titles =
      for t <- tokens,
          Regex.match?(
            ~r/\b1[89]\d\d\b|n\.\s*j|jersey|sanborn|population|water\s*fac|prevailing|scale/i,
            t.text
          ),
          do: t.center

    # ... and where it is smaller than street-name lettering: business names
    # and notes ("TRENTON PACKING CO.", Trenton 1927 Sheet 53).
    Enum.reject(labels, fn l ->
      l.key in town_keys and
        (Enum.any?(titles, &(Geometry.dist(&1, l.px) < 700)) or
           (l[:height] || @min_street_name_px) < @min_street_name_px)
    end)
  end

  @doc """
  Street names the whole-sheet OCR missed, read from 1800 px tiles at 2/3
  resolution (`Ocr.read_tiled/2`): small or vertical names (Branchville's
  Church, Broad, New). Only lettering at least #{@min_tile_name_px} px tall
  counts (smaller text is building notes); a street already read within 400 px
  is not added twice.
  """
  def tiled_labels(canvas, ocr_tokens, osm, opts) do
    if Keyword.get(opts, :tiled_labels, true) do
      have = ocr_labels(ocr_tokens, osm)

      for l <-
            canvas
            |> Ocr.read_tiled(&fetch_image/1)
            |> Enum.filter(&(&1.height >= @min_tile_name_px))
            |> ocr_labels(osm),
          not Enum.any?(have, &(&1.key == l.key and Geometry.dist(&1.px, l.px) < 400)),
          do: Map.put(l, :tiled, true)
    else
      []
    end
  end

  @doc "OCR tokens that name a modern street/railway/waterway, with direction."
  def ocr_labels(tokens, osm) do
    for t <- tokens ++ spaced_names(tokens),
        t.score >= 0.75,
        text = ordinal_fix(t.text),
        ordinal?(text) or String.length(String.replace(text, ~r/[^\p{L}]/u, "")) >= 3,
        not index_entry?(text),
        key = match_label(osm, text),
        not building_note?(key, t),
        do: %{
          name: text,
          key: key,
          px: t.center,
          angle: t.angle,
          height: Map.get(t, :height),
          source: :ocr
        }
  end

  # "CHURCH", "SCHOOL", "MILL" ... are also printed on buildings, in smaller
  # lettering (~86 px at 395 dpi) than street names (~115-170 px): Swedesboro
  # 1898 Sheet 2's two "EPISCPL CHURCH" notes matched Church Street and helped
  # hold a fit one block off. A street named after a building type must be
  # printed at street-name size.
  # ... and the colour key / materials legend ("BLDGS COLORED GREEN ARE
  # SPECIALS": Washington 1884 Sheet 1 fitted 9 degrees off with GREEN on Green
  # Street) and generic structure notes (GARAGE, STGE, BRIDGE, SCALE, W. PIPE),
  # all lettered well below street-name size in accepted fits.
  @building_words ~w(church school mill hall hotel depot station market chapel academy
                     factory college cemetery bank mills
                     red green blue yellow brown gray grey stone iron brick frame adobe metal
                     slate garage stage storage shed bridge scale sale wood pipe piper carriage
                     division lumber coal yard ridge)
  defp building_note?(key, t),
    do: key in @building_words and Map.get(t, :height, @min_street_name_px) < @min_street_name_px

  # Numbered streets print as "3RD" / "6TH" (two letters, so the 3-letter
  # minimum dropped them; Cresskill 1914 Sheet 2 then had no cross streets
  # unless the VLM read them). OCR drops the T of "7TH" as "7H".
  @ordinal ~r/^\s*\d{1,3}\s*(ST|ND|RD|TH)\.?\s*$/i
  defp ordinal?(text), do: Regex.match?(@ordinal, text)

  # Lettered streets are printed letter-spaced across the street ("B      ST."
  # on Belmar 1905 Sheet 80: the two words ~880 px apart), so OCR returns a
  # lone letter and a lone type word. Join them when the letter sits on the
  # type word's line (<= half a letter off it), the type word follows within
  # 12 letter heights, and they are lettered at a similar size. A lone
  # letter's own box angle is meaningless (taller than wide), so the line is
  # the type word's.
  @spaced_letter ~r/^\s*([A-Z])\.?\s*$/
  @spaced_type ~r/^\s*(ST|AV|AVE|RD|PL)\.?\s*$/i
  def spaced_names(tokens) do
    types = Enum.filter(tokens, &(Regex.match?(@spaced_type, &1.text) and &1.angle != nil))

    for l <- tokens,
        [_, letter] <- [Regex.run(@spaced_letter, l.text)],
        hl = Map.get(l, :height) || 0.0,
        hl > 0,
        t <- types,
        ht = Map.get(t, :height) || 0.0,
        ht / hl >= 0.6 and ht / hl <= 1.6,
        {dx, dy} = {elem(t.center, 0) - elem(l.center, 0), elem(t.center, 1) - elem(l.center, 1)},
        along = dx * :math.cos(t.angle) + dy * :math.sin(t.angle),
        across = abs(-dx * :math.sin(t.angle) + dy * :math.cos(t.angle)),
        along > 0 and along <= 12 * hl and across <= 0.5 * max(hl, ht) do
      %{
        text: "#{letter} #{String.upcase(String.trim(t.text))}",
        score: min(l.score, t.score),
        center: {elem(l.center, 0) + dx / 2, elem(l.center, 1) + dy / 2},
        angle: t.angle,
        height: max(hl, ht)
      }
    end
  end

  # ordinals and spaced single letters match exactly ("3rd" must not
  # fuzzy-match "33rd", "B ST" not "Bay St")
  defp match_label(osm, text) do
    if ordinal?(text) or Regex.match?(~r/^[A-Z] (ST|AV|AVE|RD|PL)\.?$/, text) do
      key = Osm.normalize(text)
      if Map.has_key?(osm.groups, key), do: key
    else
      Osm.match_name(osm, text)
    end
  end

  defp ordinal_fix(text), do: Regex.replace(~r/^\s*(\d{1,3})\s*H\.?\s*$/i, text, "\\1TH")

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

  # VLM zoom-in on each junction seed: off by default. Seeds only start the
  # labels-only fit; without it the check points held (Hohokus 2.0 -> 1.7 m
  # median, Cresskill 1.4 -> 1.7 m), the held-out sample fitted the same 24
  # parts within 8 m, at ~10x the speed and with no VLM server.
  defp maybe_refine(located, canvas, opts) do
    if Keyword.get(opts, :refine, false),
      do: Enum.map(located, &refine(&1, canvas)),
      else: located
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

  @doc """
  The printed border around the map drawing, as four canvas points (TL, TR,
  BR, BL); the full canvas when nothing plausible is found. Found by image
  processing (`priv/georef/neatline.py`: the outermost ruled line with blank
  margin beyond it, else where the drawing starts). `vlm_neatline: true`
  asks the VLM instead, which on 86 sheets cut real map content more often
  (Princeton 1918 Sheets 6 and 9, Millville Sheet 18).
  """
  def neatline(canvas, overview, opts \\ []) do
    if Keyword.get(opts, :vlm_neatline, false),
      do: vlm_neatline(canvas, overview),
      else: cv_neatline(canvas, overview)
  end

  defp cv_neatline(canvas, overview) do
    full = [{0, 0}, {canvas.width, 0}, {canvas.width, canvas.height}, {0, canvas.height}]
    dir = Path.expand("~/.cache/dpul_georef/py")
    File.mkdir_p!(dir)
    img = Path.join(dir, "neat#{System.unique_integer([:positive])}.jpg")
    File.write!(img, overview)
    script = Application.app_dir(:dpul_collections, "priv/georef/neatline.py")

    args =
      ~w(run -q --with numpy --with opencv-python-headless python -I) ++
        [script, img, to_string(canvas.width), to_string(canvas.height)]

    try do
      with {out, 0} <- System.cmd("uv", args),
           %{"corners" => [_, _, _, _] = corners} <-
             out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!(),
           pts = Enum.map(corners, fn [x, y] -> {x, y} end),
           true <- plausible_mask?(pts, canvas) do
        pts
      else
        _ -> full
      end
    after
      File.rm(img)
    end
  end

  defp vlm_neatline(canvas, overview) do
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

  # Image servers throttle (LoC closes sockets / answers 429 or 503 under
  # load): back off for up to ~6 minutes before giving up on an image.
  defp download(url, waits \\ [5, 15, 45, 120, 180]) do
    result =
      try do
        Req.get(url, decode_body: false, receive_timeout: 120_000, max_retries: 3)
      rescue
        e -> {:error, e}
      end

    case {result, waits} do
      {{:ok, %{status: 200, body: body}}, _} ->
        body

      {other, [w | rest]} ->
        Logger.warning(
          "georef: image fetch failed (#{inspect(other, limit: 3)}), retrying in #{w}s"
        )

        Process.sleep(w * 1000)
        download(url, rest)

      {other, []} ->
        raise "image fetch failed for #{url}: #{inspect(other, limit: 5)}"
    end
  end

  def fetch_image(url) do
    dir = Path.expand("~/.cache/dpul_georef/img")
    File.mkdir_p!(dir)
    path = Path.join(dir, Base.encode16(:crypto.hash(:md5, url)) <> ".jpg")

    if File.exists?(path) do
      File.read!(path)
    else
      body = download(url)

      # write-then-rename: a concurrent run must never read a half-written jpg
      tmp = "#{path}.#{System.unique_integer([:positive])}.tmp"
      File.write!(tmp, body)
      File.rename!(tmp, path)
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
    town = place_name(manifest)
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

  @doc """
  The place to search: the title's town, unless the catalog subject names one
  other town (the present name: Roosevelt's 1912 atlas is Carteret today).
  """
  def place_name(manifest) do
    town = town_name(manifest)

    case Map.get(manifest, :subject_places, []) do
      [other] -> if Osm.normalize(other) == Osm.normalize(town), do: town, else: other
      _ -> town
    end
  end

  @doc "The title's place name (\"Insurance maps of\" removed)."
  def town_name(manifest) do
    manifest.label
    |> to_string()
    |> String.replace(~r/^\s*insurance maps? of\s+/i, "")
    |> String.split([",", "[", ":"])
    |> hd()
    |> String.trim()
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
