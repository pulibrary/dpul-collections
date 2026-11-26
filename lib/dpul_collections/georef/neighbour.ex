defmodule DpulCollections.Georef.Neighbour do
  @moduledoc """
  Placement of a declined part from the fitted sheets around it, for parts
  with too few readable street names to fit on their own (two or three
  labels, often all on parallel streets).

  Scale and rotation come from priors, so each label constrains only the
  translation: the printed scale, else the scale class of the neighbouring
  fitted sheets (`Slide.scales_ft/3`), else the class of the fitted sheets
  the part references at its edges, else both classes; the rotation is the
  atlas rotation (circular median of the fitted sheets, mod 90 degrees) plus
  k x 90 degrees. `priv/georef/neighbour.py` lists the translations where
  labels of two different streets land on their streets, ranks them, and
  verifies the best #{8} against every street name on the sheet (OCR'd in
  tiles at higher resolution, `Ocr.read_tiled/2`) and against the
  adjacent-sheet numbers printed at its edges.

  Only the strongest acceptance rule is used: no contradicting name or sheet
  reference, at most half of a fitted footprint covered, and at least
  #{2} names read on their streets, one of them informative (on a crossing
  street when the labels are all parallel), with no equally supported rival
  placement. The final fit holds scale and rotation and fits the translation
  to the labels plus the reads.
  """
  require Logger

  alias DpulCollections.Georef.{Consistency, Mask, Ocr, Osm, Py, Slide}

  # Sanborn street names are ~115-145 px tall at ~395 dpi; building notes 55-80.
  @min_name_px 78
  @min_score 0.8
  # tokens this far inside the part (canvas px)
  @inset 20
  # adjacent-sheet numbers are printed large, in or just outside the part
  @ref_px {170, 330}
  @ref_reach 400
  @region_pad 2500.0
  @top 8

  @doc """
  The atlas context shared by every placement: the fitted neighbours (atlas
  sheets, not key maps, and not parts `Consistency` is about to decline), the
  canvas order and the search region.
  """
  def context(results, manifest, osm, exclude_keys, tokens_of) do
    doomed = results |> Consistency.losers(tokens_of) |> MapSet.new(fn {r, _} -> id(r) end)

    fitted =
      results
      |> Enum.filter(&(&1.status == :ok))
      |> Consistency.sheets()
      |> Enum.reject(&(id(&1) in doomed))

    index = manifest.canvases |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, i} end)
    footprints = Enum.flat_map(fitted, &Consistency.footprint/1)

    %{
      results: results,
      fitted: fitted,
      index: index,
      osm: osm,
      exclude: exclude_keys,
      names: street_names(osm),
      region:
        if(footprints != [],
          do: footprints |> Mask.bbox() |> pad(@region_pad),
          else: nil
        )
    }
  end

  defp id(r), do: {r.canvas.id, r.part}
  defp pad({a, b, c, d}, m), do: [a - m, b - m, c + m, d + m]

  @doc "A declined part qualifies when its labels name at least two modern streets."
  def eligible?(r, osm, exclude_keys) do
    r.status == :failed and not Map.get(r, :conflict, false) and
      r.labels |> usable_labels(osm, exclude_keys) |> Enum.uniq_by(& &1.key) |> length() >= 2
  end

  defp usable_labels(labels, osm, exclude_keys) do
    Enum.filter(labels, fn l ->
      l.key not in exclude_keys and match?(%{kind: :street}, osm.groups[l.key])
    end)
  end

  @doc """
  Place one declined part. Returns `%{t, labels, hits}` (the transform, the
  confirming reads as extra labels, labels on their streets after the final
  fit) or nil.
  """
  def place(r, ctx, fetch_image) do
    if ctx.fitted == [], do: nil, else: do_place(r, ctx, fetch_image)
  end

  defp do_place(r, ctx, fetch_image) do
    tokens = Ocr.read_tiled(r.canvas, fetch_image)
    sheets = ctx.fitted |> Enum.map(&sheet_number(&1.label)) |> MapSet.new()
    siblings = for s <- ctx.results, s.canvas.id == r.canvas.id, s.part != r.part, do: s.mask

    refs =
      tokens
      |> sheet_refs(r.mask, siblings, sheet_number(r.label))
      |> Enum.filter(fn {n, _} -> n in sheets end)

    scales = scales_ft(r, ctx, refs)
    labels = usable_labels(r.labels, ctx.osm, ctx.exclude)

    input = %{
      width: r.canvas.width,
      mask: Enum.map(r.mask, &Tuple.to_list/1),
      labels:
        Enum.map(labels, fn l ->
          %{px: Tuple.to_list(l.px), key: l.key, angle: if(l.source == :ocr, do: l.angle)}
        end),
      fitted:
        Enum.map(ctx.fitted, fn f ->
          %{
            sheet: sheet_number(f.label),
            mask: Enum.map(f.mask, &Tuple.to_list/1),
            t: f.transform
          }
        end),
      scales: Enum.map(scales, &Slide.m_per_px/1),
      rotation: atlas_rotation(Enum.map(ctx.fitted, & &1.transform)),
      region: ctx.region,
      tokens: name_tokens(tokens, r.mask, ctx.names),
      refs: Enum.map(refs, fn {n, px} -> %{n: n, px: Tuple.to_list(px)} end),
      neutral: ctx.exclude,
      top: @top
    }

    jpg = fetch_image.(Slide.overview_url(r.canvas))
    out = Py.run("neighbour.py", input, jpg, ctx.osm, ctx.exclude, ["shapely"])

    Logger.info(
      "georef: #{r.label} neighbour search at #{Enum.join(scales, "/")} ft, refs #{inspect(Enum.map(refs, &elem(&1, 0)))} (#{out["pass"]}): " <>
        Enum.map_join(out["hyps"], "; ", fn h ->
          "#{h["ft"]}ft k=#{h["k"]} ov=#{h["overlap"]} reads=#{inspect(h["reads"])} " <>
            "contra=#{length(h["contras"])} refs+#{length(h["refs_ok"])}-#{length(h["refs_bad"])}" <>
            if(h["accepted"], do: " ACC", else: "")
        end)
    )

    case out["best"] do
      %{"t" => t, "reads" => reads, "hits" => hits} ->
        %{
          t: Map.new(t, fn {k, v} -> {String.to_existing_atom(k), v} end),
          hits: hits,
          labels:
            Enum.map(reads, fn %{"key" => k, "text" => text, "px" => [x, y]} ->
              %{name: text, key: k, px: {x, y}, angle: nil, source: :neighbour}
            end)
        }

      _ ->
        nil
    end
  end

  @doc """
  Feet-per-inch scales to search: `Slide.scales_ft/3` (printed, or agreeing
  neighbours in canvas order), else the single scale class of the fitted
  sheets referenced at the part's edges (`refs` = [{sheet, px}]), else both.
  """
  def scales_ft(r, ctx, refs) do
    fitted = for f <- ctx.fitted, do: {ctx.index[f.canvas.id], f.scale}

    # a fitted part of the same sheet is drawn at the part's scale unless the
    # part states its own (Avon 1905 Sheet 64: 60 ft, which the 50/100 ft
    # classes round away)
    siblings =
      for f <- ctx.fitted, f.canvas.id == r.canvas.id, uniq: true, do: sheet_ft(f.scale)

    if r.printed_scale_ft == nil and siblings != [],
      do: siblings,
      else: classes_ft(r, ctx, refs, fitted)
  end

  @sheet_ft [50, 60, 100, 120, 200, 300, 400, 500, 600, 800, 1000]
  defp sheet_ft(m_per_px) do
    ft = m_per_px * 395 / 0.3048
    Enum.min_by(@sheet_ft, &abs(:math.log(ft / &1)))
  end

  defp classes_ft(r, ctx, refs, fitted) do
    case Slide.scales_ft(r.printed_scale_ft, fitted, ctx.index[r.canvas.id]) do
      {[ft], _} ->
        [ft]

      {both, _} ->
        referenced = MapSet.new(refs, &elem(&1, 0))

        ctx.fitted
        |> Enum.filter(&(sheet_number(&1.label) in referenced))
        |> Enum.map(&Slide.scale_class(&1.scale))
        |> Enum.uniq()
        |> case do
          [ft] -> [ft]
          _ -> both
        end
    end
  end

  @doc """
  The atlas rotation (radians, Georef.Geometry's angle of {a, b}) modulo 90
  degrees: the circular median of the fitted sheets' rotations. Sheets are
  printed square to the street grid, so their rotations differ by k x 90.
  """
  def atlas_rotation(transforms) do
    zs = Enum.map(transforms, &(4 * :math.atan2(&1.b, &1.a)))
    re = zs |> Enum.map(&:math.cos/1) |> median()
    im = zs |> Enum.map(&:math.sin/1) |> median()
    :math.atan2(im, re) / 4
  end

  # numpy's median (mean of the middle two)
  defp median(xs) do
    s = Enum.sort(xs)
    n = length(s)

    if rem(n, 2) == 1,
      do: Enum.at(s, div(n, 2)),
      else: (Enum.at(s, div(n, 2) - 1) + Enum.at(s, div(n, 2))) / 2
  end

  @doc "The sheet number in a part label (\"Sheet 16 (part 2)\" -> 16), or nil."
  def sheet_number(label) do
    case Regex.run(~r/Sheet (\d+)/, label || "") do
      [_, n] -> String.to_integer(n)
      _ -> nil
    end
  end

  @doc """
  Adjacent-sheet numbers printed large in or next to the part (within
  #{@ref_reach} px outside it), as [{sheet, px}]: not its own number, and not
  closer to (inside) a sibling part of the same canvas.
  """
  def sheet_refs(tokens, mask, siblings, own) do
    for t <- tokens,
        text = String.trim(t.text),
        Regex.match?(~r/^\d{1,2}$/, text),
        n = String.to_integer(text),
        n != own,
        t.height >= elem(@ref_px, 0) and t.height <= elem(@ref_px, 1),
        d = Mask.signed_distance(t.center, mask),
        d > -@ref_reach,
        not Enum.any?(siblings, &(Mask.signed_distance(t.center, &1) > max(-50, d))),
        do: {n, t.center}
  end

  # Street-name lettering inside the part with the street keys it may name.
  defp name_tokens(tokens, mask, names) do
    tokens
    |> Enum.filter(fn t ->
      t.score >= @min_score and t.height >= @min_name_px and
        Mask.signed_distance(t.center, mask) > @inset
    end)
    |> Enum.map(&%{text: &1.text, px: Tuple.to_list(&1.center), keys: name_keys(&1.text, names)})
    |> Enum.reject(&(&1.keys == []))
  end

  @doc "Raw OSM names per street key, for `name_keys/2`."
  def street_names(%Osm{features: features}) do
    for f <- features, f.kind == :street, k <- f.keys, reduce: %{} do
      acc -> Map.update(acc, k, MapSet.new(f.names), &MapSet.union(&1, MapSet.new(f.names)))
    end
  end

  @directions ~w(north south east west n s e w)
  @types ~w(avenue street boulevard road lane place court drive)
  @long %{
    "n" => "north",
    "s" => "south",
    "e" => "east",
    "w" => "west",
    "av" => "avenue",
    "ave" => "avenue",
    "st" => "street",
    "blvd" => "boulevard",
    "rd" => "road",
    "ln" => "lane",
    "pl" => "place",
    "ct" => "court",
    "dr" => "drive"
  }

  @doc """
  Street keys a token read off the sheet may name (`names` = key => raw OSM
  names). Stricter than `Osm.match_name/2`, since a read here can contradict
  a placement: short or digit-only reads name nothing, ordinals must match
  exactly, others fuzzily (Jaro >= 0.9, length within 1). A read made only of
  direction words is compared in long form with the OSM names: "S.E.
  BOULEVARD" names South East Boulevard, but a bare "WEST" names nothing
  (West Avenue or West Boulevard?).
  """
  def name_keys(text, names) do
    key = Osm.normalize(text)
    words = String.split(key)
    ordinal? = ordinal?(key)

    cond do
      words != [] and Enum.all?(words, &(&1 in @directions)) ->
        direction_keys(text, names)

      String.length(key) < if(ordinal?, do: 3, else: 4) or not Regex.match?(~r/\p{L}/u, key) ->
        []

      ordinal? ->
        if Map.has_key?(names, key), do: [key], else: []

      true ->
        for {k, _} <- names,
            k == key or
              (abs(String.length(k) - String.length(key)) <= 1 and not ordinal?(k) and
                 String.jaro_distance(k, key) >= 0.9),
            do: k
    end
  end

  defp ordinal?(key), do: Regex.match?(~r/^\d+(st|nd|rd|th)$/, key)

  defp direction_keys(text, names) do
    long = long_form(text)

    if length(String.split(long)) < 2 do
      []
    else
      for {k, ns} <- names,
          Enum.any?(ns, fn n ->
            l = long_form(n)
            {stem, type} = split_last(l)
            l == long or (stem == long and type in @types)
          end),
          do: k
    end
  end

  defp long_form(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9 ]/, " ")
    |> String.split()
    |> Enum.map_join(" ", &Map.get(@long, &1, &1))
  end

  defp split_last(s) do
    case String.split(s, " ") |> Enum.split(-1) do
      {stem, [last]} -> {Enum.join(stem, " "), last}
      _ -> {"", s}
    end
  end
end
