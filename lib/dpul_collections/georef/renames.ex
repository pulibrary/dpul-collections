defmodule DpulCollections.Georef.Renames do
  @moduledoc """
  Street renames learned from an atlas's own fitted sheets. Every street-name
  sized word that sits on a modern centreline, in its direction, on a sheet
  that did fit, is a vote for that street: a name matching no modern street
  ("MAIN" in Swedesboro, now Kings Highway), or matching one far away
  (Branchville's MAIN printed on today's Mill Street while a modern Main
  Street exists elsewhere), or simply its own street. A name whose votes agree
  (>= #{2}, >= 75 %) on a different street becomes an alias for the atlas's
  declined sheets (`Osm.with_aliases/2`, which then replaces that name).
  """
  alias DpulCollections.Georef.{Geometry, Mask, Osm}

  # metres from the centreline, degrees off its direction
  @tolerance 8.0
  @max_angle 20
  # street-name lettering (pipeline px at 395 dpi); building notes are smaller
  @min_px 100
  @min_obs 2
  @min_agreement 0.75

  @doc """
  [{printed key, modern key}] for the unmatched street-name-sized tokens of one
  fitted part. `exclude` are keys never learned (the town's own name).
  """
  def observe(result, tokens, osm, exclude \\ [])

  def observe(%{status: :ok, transform: t, mask: mask}, tokens, osm, exclude) do
    for tok <- tokens,
        tok.score >= 0.8,
        Map.get(tok, :height, 0) >= @min_px,
        tok.angle != nil,
        Mask.inside_polygon?(tok.center, mask),
        String.length(String.replace(tok.text, ~r/[^\p{L}]/u, "")) >= 3,
        not Regex.match?(~r/,|\.\./, tok.text),
        key = Osm.match_name(osm, tok.text) || Osm.normalize(tok.text),
        key != "",
        not Osm.suffix_only?(key),
        key not in exclude,
        modern = on_street(t, tok, osm),
        modern != nil,
        do: {key, modern}
  end

  def observe(_, _, _, _), do: []

  # the street whose centreline the token sits on, running its way
  defp on_street(t, %{center: {u, v} = c, angle: a}, osm) do
    w = Geometry.transform(t, c)
    {wx, wy} = Geometry.transform(t, {u + 100 * :math.cos(a), v + 100 * :math.sin(a)})
    dir = :math.atan2(wy - elem(w, 1), wx - elem(w, 0))

    osm.groups
    |> Enum.filter(fn {_, g} -> g.kind == :street end)
    |> Enum.flat_map(fn {key, g} ->
      for {{x1, y1}, {x2, y2}} = seg <- g.segments,
          d = Geometry.point_segment_dist(w, seg),
          d <= @tolerance,
          angle_between(dir, :math.atan2(y2 - y1, x2 - x1)) <= @max_angle,
          do: {d, key}
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> nil
      {_, key} -> key
    end
  end

  defp angle_between(a, b) do
    d = abs(a - b) |> :math.fmod(:math.pi())
    min(d, :math.pi() - d) * 180 / :math.pi()
  end

  @doc "%{printed key => %{modern key => votes}}"
  def vote_counts(observations) do
    observations
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {printed, moderns} -> {printed, Enum.frequencies(moderns)} end)
  end

  @doc "%{printed key => modern key} from observations: >= #{@min_obs} agreeing, >= #{@min_agreement} of them."
  def table(observations) do
    observations
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {printed, moderns} ->
      {modern, n} = moderns |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1))

      if n >= @min_obs and n / length(moderns) >= @min_agreement and modern != printed,
        do: [{printed, modern}],
        else: []
    end)
    |> Map.new()
  end
end
