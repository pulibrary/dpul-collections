defmodule DpulCollections.Georef.Slide do
  @moduledoc """
  Fallback for declined parts whose readable street names are all on one
  family of PARALLEL streets: those labels fix rotation and the offset across
  the streets, but a fit can slide along them.

  `priv/georef/slide.py` searches placements along the family at Sanborn's
  standard scales (ranked by how well modern centrelines fall into printed
  street corridors) and, for each of the top #{8}, predicts named cross
  streets and mid-block points where their names should be printed. Here each
  point is read (OCR, then the VLM if OCR read no street name): a read naming
  a street within #{20} m of the point confirms the placement, one naming a
  real street more than #{60} m away contradicts it. The best placement with a
  confirmation and no contradiction is returned with the confirming reads as
  extra labels; acceptance is left to the normal labels-only fit and gates.
  """
  require Logger

  alias DpulCollections.Georef.{Geometry, Manifest, Ocr, Osm, Py, Vlm}

  @top 8
  @crop 1200
  # read points keep this far inside the part (the prototype's 800 px crop x 0.4)
  @edge 320
  @match_m 20.0
  @contra_m 60.0
  @family_tolerance_deg 12
  @standard_ft [50, 100]
  @scan_dpi 395

  @doc """
  A declined part qualifies when its labels give no crossing pair (no
  label-line junction: no two labels of streets that meet in OSM cross) but
  do contain a family of parallel streets.
  """
  def eligible?(result, exclude_keys) do
    result.status == :failed and
      not Enum.any?(result.located, &(&1[:source] == :labels)) and
      families(result.labels, exclude_keys) != []
  end

  @doc """
  Families of OCR labels printed in one direction (within
  #{@family_tolerance_deg} degrees) naming at least two different streets,
  largest first, without families contained in another. VLM labels carry no
  real direction.
  """
  def families(labels, exclude_keys \\ []) do
    ls =
      Enum.filter(labels, &(&1.source == :ocr and &1.angle != nil and &1.key not in exclude_keys))

    fams =
      ls
      |> Enum.map(fn l ->
        Enum.filter(ls, &(angle_deg(&1.angle, l.angle) < @family_tolerance_deg))
      end)
      |> Enum.uniq()
      |> Enum.filter(&(distinct_keys(&1) >= 2))

    fams
    |> Enum.reject(fn f -> Enum.any?(fams, &(&1 != f and subset?(f, &1))) end)
    |> Enum.sort_by(&(-distinct_keys(&1)))
  end

  defp distinct_keys(fam), do: fam |> Enum.map(& &1.key) |> Enum.uniq() |> length()
  defp subset?(a, b), do: MapSet.subset?(MapSet.new(a), MapSet.new(b))

  # acute angle between two undirected lines, degrees
  defp angle_deg(a, b) do
    d = abs(a - b) |> :math.fmod(:math.pi())
    min(d, :math.pi() - d) * 180 / :math.pi()
  end

  @doc """
  Feet-per-inch scales to search and the confirming reads required, as
  `{scales, min_matches}`. A printed scale wins. Otherwise the scale class
  (#{inspect(@standard_ft)} ft) of the previous and next fitted sheets in
  canvas order (`fitted` = [{canvas_index, m_per_px}]; the part's own canvas
  counts as both) when both exist and agree; atlases mix scales, so no
  manifest-wide class. Otherwise both classes are searched and a placement
  needs two confirming reads.
  """
  def scales_ft(printed_ft, _fitted, _index) when is_integer(printed_ft), do: {[printed_ft], 1}

  def scales_ft(nil, fitted, index) do
    before = nearest_canvas(for({i, _} = f <- fitted, i <= index, do: f), &Enum.max/1)
    later = nearest_canvas(for({i, _} = f <- fitted, i >= index, do: f), &Enum.min/1)

    # Both sides must have a fitted sheet: one far-off fitted sheet on one side
    # says little (Vineland 2-17 are 50 ft, 18-26 100 ft).
    case before != [] and later != [] and
           (before ++ later) |> Enum.map(fn {_, m} -> scale_class(m) end) |> Enum.uniq() do
      [ft] -> {[ft], 1}
      _ -> {@standard_ft, 2}
    end
  end

  # every fitted part of the nearest fitted canvas on one side
  defp nearest_canvas([], _pick), do: []

  defp nearest_canvas(fitted, pick) do
    i = fitted |> Enum.map(&elem(&1, 0)) |> pick.()
    Enum.filter(fitted, &(elem(&1, 0) == i))
  end

  @doc "The standard scale (ft to the inch) nearest a fitted m/px at #{@scan_dpi} dpi."
  def scale_class(m_per_px) do
    ft = m_per_px * @scan_dpi / 0.3048
    Enum.min_by(@standard_ft, &abs(:math.log(ft / &1)))
  end

  @doc "Metres per canvas px of a \"ft to the inch\" scale at #{@scan_dpi} dpi."
  def m_per_px(ft), do: ft * 0.3048 / @scan_dpi

  @doc """
  Search the part's families and read the predicted cross streets. Returns
  `%{t, labels, reads}` for the best confirmed placement (at least
  `min_matches` confirming reads and no contradiction; most confirming reads,
  then corridor score), or nil.
  """
  def confirm(result, osm, {scales_ft, min_matches}, exclude_keys, fetch_image) do
    fams = families(result.labels, exclude_keys)

    fams
    |> search(result, osm, scales_ft, exclude_keys, fetch_image)
    |> Enum.find_value(fn %{"keys" => keys, "hyps" => hyps} ->
      read = read_hypotheses(hyps, result.canvas, osm, keys ++ exclude_keys, fetch_image)

      Logger.info(
        "georef: #{result.label} slide family #{inspect(keys)} at #{Enum.join(scales_ft, "/")} ft (#{min_matches} read(s) needed), reads per placement matches/contradictions: " <>
          Enum.map_join(read, " ", &"#{&1.matches}/#{&1.contras}")
      )

      read
      |> Enum.filter(&(&1.matches >= min_matches and &1.contras == 0))
      |> Enum.max_by(&{&1.matches, &1.score}, fn -> nil end)
    end)
  end

  defp search(fams, result, osm, scales_ft, exclude_keys, fetch_image) do
    canvas = result.canvas

    input = %{
      width: canvas.width,
      mask: Enum.map(result.mask, &Tuple.to_list/1),
      families:
        Enum.map(fams, fn f ->
          Enum.map(f, &%{px: Tuple.to_list(&1.px), key: &1.key, angle: &1.angle})
        end),
      scales: Enum.map(scales_ft, &m_per_px/1),
      top: @top,
      edge: @edge
    }

    # The corridor score was tuned on a 1600 px wide overview.
    jpg = fetch_image.(overview_url(canvas))
    %{"families" => families} = Py.run("slide.py", input, jpg, osm, exclude_keys)
    families
  end

  @doc "The 1600 px wide canvas image the corridor score was tuned on."
  def overview_url(canvas), do: "#{canvas.service_id}/full/1600,/0/default.jpg"

  # Read every hypothesis' predicted cross streets in rounds: round r reads
  # the r-th point of each street not yet decided (a second point only when
  # the first read nothing useful). OCR reads a round's crops in one batch;
  # the VLM reads only crops where OCR found no street name at all.
  defp read_hypotheses(hyps, canvas, osm, neutral_keys, fetch_image) do
    hyps =
      Enum.map(hyps, fn %{"t" => t, "score" => score, "cross" => cross} ->
        t = %{a: t["a"], b: t["b"], tx: t["tx"], ty: t["ty"]}
        %{t: t, score: score, cross: cross, matches: 0, contras: 0, labels: [], reads: []}
      end)

    pending =
      for {h, hi} <- Enum.with_index(hyps),
          %{"key" => key, "pts" => pts} <- h.cross,
          do: {hi, key, Enum.map(pts, fn [x, y] -> {x, y} end)}

    read_rounds(List.to_tuple(hyps), pending, canvas, osm, neutral_keys, fetch_image)
    |> Tuple.to_list()
    |> Enum.map(&Map.take(&1, [:t, :score, :matches, :contras, :labels, :reads]))
  end

  defp read_rounds(hyps, [], _canvas, _osm, _neutral, _fetch), do: hyps

  defp read_rounds(hyps, pending, canvas, osm, neutral_keys, fetch_image) do
    jobs =
      Enum.map(pending, fn {hi, key, [pt | rest]} ->
        region = crop_region(canvas, pt)
        jpg = fetch_image.(Manifest.image_url(canvas, region, @crop))
        %{hi: hi, key: key, pt: pt, rest: rest, region: region, jpg: jpg}
      end)

    ocr = Ocr.read_images(Enum.map(jobs, & &1.jpg))
    vlm_before = Process.get(:slide_vlm_reads, 0)

    {hyps, next} =
      jobs
      |> Enum.zip(ocr)
      |> Enum.reduce({hyps, []}, fn {job, tokens}, {hyps, next} ->
        h = elem(hyps, job.hi)
        wpt = Geometry.transform(h.t, job.pt)
        read = read_crop(job, tokens, wpt, osm, neutral_keys)
        h = %{h | reads: [{job.key, read.text, read.class} | h.reads]}

        h =
          case read.class do
            {:match, key} ->
              label = %{name: read.text, key: key, px: read.px, angle: read.angle, source: :slide}
              %{h | matches: h.matches + 1, labels: [label | h.labels]}

            :contra ->
              %{h | contras: h.contras + 1}

            _ ->
              h
          end

        undecided = read.class in [nil, :neutral] and job.rest != []
        next = if undecided, do: [{job.hi, job.key, job.rest} | next], else: next
        {put_elem(hyps, job.hi, h), next}
      end)

    Logger.info(
      "georef: slide read round: #{length(jobs)} crops OCR'd, " <>
        "#{Process.get(:slide_vlm_reads, 0) - vlm_before} read by the VLM"
    )

    read_rounds(hyps, Enum.reverse(next), canvas, osm, neutral_keys, fetch_image)
  end

  # Every OCR line in the crop is classified at the predicted point; a match
  # wins, then a contradiction. Without any street name from OCR the crop is
  # unread; the VLM is asked only with --slide-vlm (its reads changed no result
  # on three atlases and cost ~5 min per sheet: Belmar 1905).
  defp read_crop(job, tokens, wpt, osm, neutral_keys) do
    {x0, y0, _, _} = job.region

    reads =
      for t <- tokens do
        {cx, cy} = t.center

        %{
          text: t.text,
          class: classify_read(t.text, wpt, osm, neutral_keys),
          px: {x0 + cx, y0 + cy},
          angle: t.angle
        }
      end

    best =
      Enum.find(reads, &match?({:match, _}, &1.class)) ||
        Enum.find(reads, &(&1.class == :contra)) ||
        Enum.find(reads, &(&1.class == :neutral))

    cond do
      best -> best
      Process.get(:slide_vlm, false) -> vlm_read(job, wpt, osm, neutral_keys)
      true -> %{text: nil, class: nil, px: nil, angle: nil}
    end
  end

  @read_prompt """
  This is a crop of a historical fire insurance map. Read the name of the street printed \
  along the street that runs through this crop (ignore building labels, company names and \
  numbers). Answer only JSON {"text": "...", "point_2d": [x, y]} with point_2d the centre of \
  that printed street name, or {"text": null, "point_2d": null} if no street name is printed.
  """

  @read_schema %{
    "type" => "object",
    "properties" => %{
      "text" => %{"anyOf" => [%{"type" => "string"}, %{"type" => "null"}]},
      "point_2d" => %{
        "anyOf" => [
          %{
            "type" => "array",
            "items" => %{"type" => "number"},
            "minItems" => 2,
            "maxItems" => 2
          },
          %{"type" => "null"}
        ]
      }
    },
    "required" => ["text", "point_2d"]
  }

  defp vlm_read(job, wpt, osm, neutral_keys) do
    {x0, y0, w, h} = job.region
    Process.put(:slide_vlm_reads, Process.get(:slide_vlm_reads, 0) + 1)

    # an unreachable VLM (GEOREF_HOST down) leaves the crop unread, not the run crashed
    answer =
      try do
        Vlm.ask_json(job.jpg, @read_prompt, max_tokens: 200, schema: @read_schema)
      rescue
        e ->
          Logger.warning("georef: slide VLM read skipped: #{Exception.message(e)}")
          :error
      end

    case answer do
      {:ok, %{"text" => text} = r} when is_binary(text) ->
        px =
          case r["point_2d"] do
            [x, y] when is_number(x) and is_number(y) -> {x0 + x / 1000 * w, y0 + y / 1000 * h}
            _ -> job.pt
          end

        %{text: text, class: classify_read(text, wpt, osm, neutral_keys), px: px, angle: nil}

      _ ->
        %{text: nil, class: nil, px: nil, angle: nil}
    end
  end

  @doc """
  Classify a name read near world point `wpt`: `{:match, key}` if a street of
  that name passes within #{@match_m} m, `:contra` if it names a real street
  that passes nowhere within #{@contra_m} m, `:neutral` for a street in
  `neutral_keys` (the family, the town) or in between, nil if it names no
  street (or is too short to trust).
  """
  def classify_read(text, wpt, osm, neutral_keys) do
    key = Osm.normalize(text)
    min_len = if Regex.match?(~r/^\d+(st|nd|rd|th)$/, key), do: 3, else: 4

    keys =
      if String.length(key) < min_len,
        do: [],
        else:
          for(
            {k, %{kind: :street}} <- osm.groups,
            k == key or String.jaro_distance(k, key) >= 0.9,
            do: k
          )

    cond do
      keys == [] ->
        nil

      Enum.any?(keys, &(&1 in neutral_keys)) ->
        :neutral

      true ->
        {k, d} =
          keys |> Enum.map(&{&1, Osm.distance_to(osm, &1, wpt)}) |> Enum.min_by(&elem(&1, 1))

        cond do
          d < @match_m -> {:match, k}
          d > @contra_m -> :contra
          true -> :neutral
        end
    end
  end

  # A full-resolution square crop centred on the point, shifted (not shrunk)
  # to stay on the canvas.
  defp crop_region(canvas, {u, v}) do
    c = min(@crop, min(canvas.width, canvas.height))

    {round(min(max(u - c / 2, 0), canvas.width - c)),
     round(min(max(v - c / 2, 0), canvas.height - c)), c, c}
  end
end
