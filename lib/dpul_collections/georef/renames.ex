defmodule DpulCollections.Georef.Renames do
  @moduledoc """
  Street renames learned from an atlas's own fitted sheets. Volunteers'
  browsers vote (assets/js/georeferencer/pipeline.js `observeRenames`): every
  street-name sized word that sits on a modern centreline, in its direction, on
  a sheet that did fit, is a vote for that street: a name matching no modern street
  ("MAIN" in Swedesboro, now Kings Highway), or matching one far away
  (Branchville's MAIN printed on today's Mill Street while a modern Main
  Street exists elsewhere), or simply its own street. A name whose votes agree
  (>= #{2}, >= 75 %) on a different street becomes an alias for the atlas's
  declined sheets (`Osm.with_aliases/2`, which then replaces that name).
  """

  @min_obs 2
  @min_agreement 0.75

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
