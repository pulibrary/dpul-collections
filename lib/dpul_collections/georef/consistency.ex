defmodule DpulCollections.Georef.Consistency do
  @moduledoc """
  Atlas-level sanity check after every part has been fitted.

  Sheets drawn at the same scale tile the town with small overlaps at their
  edges, so two same-scale parts whose ground footprints overlap by more than
  half cannot both be right. On regular street grids a sheet can be fitted
  one block off with every label on a (wrong but parallel) street, which no
  per-sheet gate catches (Vineland 1925 Sheet 11: 73 % on top of Sheet 12).

  A fitted key map (a small-scale part: the atlas overview) settles such a
  conflict when it prints one sheet's number inside that sheet's footprint;
  otherwise both parts are declined — no annotation beats a wrong one.
  """
  alias DpulCollections.Georef.{Geometry, Mask}

  @max_overlap 0.5
  # same scale class: 50 vs 100 ft to an inch differ by 2x
  @same_scale 1.3
  # a key map is drawn at >= 4x the m/px of the sheets it indexes
  @key_map_ratio 4.0

  @doc "Pairs of same-scale fitted parts overlapping by more than half of the smaller one."
  def conflicts(fitted) do
    for {a, i} <- Enum.with_index(fitted),
        {b, j} <- Enum.with_index(fitted),
        i < j,
        same_scale?(a.scale, b.scale),
        overlap(footprint(a), footprint(b)) > @max_overlap,
        do: {a, b}
  end

  @doc """
  The fitted parts to decline, each with the part it conflicts with, as
  `[{loser, other}]` (a part may appear once per conflict). `tokens_of`
  returns a canvas's OCR tokens (key maps' sheet numbers are read from them).
  """
  def losers(results, tokens_of) do
    fitted = Enum.filter(results, &(&1.status == :ok))
    keys = key_map_numbers(fitted, tokens_of)

    for {a, b} <- conflicts(fitted), r <- losers(a, b, keys), do: {r, if(r == a, do: b, else: a)}
  end

  defp median_scale(fitted),
    do: fitted |> Enum.map(& &1.scale) |> Enum.sort() |> Enum.at(div(length(fitted), 2))

  defp losers(a, b, keys) do
    case {vouched?(a, keys), vouched?(b, keys)} do
      {true, false} -> [b]
      {false, true} -> [a]
      _ -> [a, b]
    end
  end

  defp same_scale?(s1, s2), do: max(s1, s2) / min(s1, s2) < @same_scale

  def footprint(r), do: Enum.map(r.mask, &Geometry.transform(r.transform, &1))

  @doc "Fraction of the smaller polygon's area that lies inside the other (grid sampled)."
  def overlap(p, q) do
    {small, big} = if Mask.area(p) <= Mask.area(q), do: {p, q}, else: {q, p}
    {x0, y0, x1, y1} = Mask.bbox(small)
    n = 40

    pts =
      for i <- 0..(n - 1),
          j <- 0..(n - 1),
          pt = {x0 + (i + 0.5) * (x1 - x0) / n, y0 + (j + 0.5) * (y1 - y0) / n},
          Mask.inside_polygon?(pt, small),
          do: pt

    if pts == [],
      do: 0.0,
      else: Enum.count(pts, &Mask.inside_polygon?(&1, big)) / length(pts)
  end

  # Big sheet numbers printed on fitted key maps, as {number, ground xy}.
  defp key_map_numbers([], _), do: []

  defp key_map_numbers(fitted, tokens_of) do
    median = median_scale(fitted)

    for k <- fitted, k.scale >= @key_map_ratio * median, {n, px} <- numbers(k, tokens_of) do
      {n, Geometry.transform(k.transform, px)}
    end
  end

  # Sheet numbers stand out by size from the street names and index text.
  defp numbers(k, tokens_of) do
    tokens = Enum.filter(tokens_of.(k.canvas), &Mask.inside_polygon?(&1.center, k.mask))
    heights = tokens |> Enum.map(&height/1) |> Enum.sort()
    median = Enum.at(heights, div(length(heights), 2)) || 0

    for t <- tokens,
        t.score > 0.8,
        Regex.match?(~r/^\d{1,3}$/, String.trim(t.text)),
        height(t) >= 1.5 * median,
        do: {String.to_integer(String.trim(t.text)), t.center}
  end

  defp height(%{quad: [a, b, _, d]}), do: min(Geometry.dist(a, d), Geometry.dist(a, b))

  defp vouched?(r, keys) do
    case Regex.run(~r/Sheet (\d+)/, r.label) do
      [_, n] ->
        n = String.to_integer(n)
        fp = footprint(r)
        Enum.any?(keys, fn {k, xy} -> k == n and Mask.inside_polygon?(xy, fp) end)

      _ ->
        false
    end
  end
end
