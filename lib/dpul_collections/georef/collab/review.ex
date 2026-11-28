defmodule DpulCollections.Georef.Collab.Review do
  @moduledoc """
  The parts volunteers' browsers couldn't place with confidence, for a person
  to place, easiest first: a guess whose printed streets line up with the
  modern ones, then a guess that collides with another sheet, then parts with
  street names but no believable guess, then parts with almost nothing to go on.
  """
  import Ecto.Query
  alias DpulCollections.Repo
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Atlas, Contribution, Job}

  @table __MODULE__

  @doc """
  Parts waiting for a person, easiest first. Building an atlas's items reads
  all its results (over a thousand atlases: seconds), so each atlas's items are
  kept (in the ETS table `init_cache/0` makes) until its jobs, contributions or
  record change; see `stamps/0`.
  """
  def items do
    stamps = stamps()

    stamps
    |> Enum.flat_map(fn {id, stamp} -> cached_items(id, stamp) end)
    |> Enum.sort_by(&{-&1.ease, &1.atlas_label, &1.index})
  end

  @doc "Makes the cache table; the application starts its owner (see `DpulCollections.Application`)."
  def init_cache do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
  end

  defp cached_items(id, stamp) do
    cache? =
      Application.get_env(:dpul_collections, :review_cache, true) and
        :ets.whereis(@table) != :undefined

    case cache? && :ets.lookup(@table, id) do
      [{^id, ^stamp, items}] ->
        items

      _ ->
        items = atlas_items(id)
        if cache?, do: :ets.insert(@table, {id, stamp, items})
        items
    end
  end

  # what an atlas's items depend on, per atlas: anything that changes them changes this (queue
  # updates through update_all leave updated_at alone, hence the counts and finish times)
  defp stamps do
    jobs =
      Repo.all(
        from j in Job,
          group_by: j.atlas_id,
          select:
            {j.atlas_id,
             {count(), filter(count(), j.status == "done"), max(j.finished_at), max(j.updated_at)}}
      )
      |> Map.new()

    contributions =
      Repo.all(
        from c in Contribution,
          group_by: c.atlas_id,
          select: {c.atlas_id, {count(), max(c.inserted_at)}}
      )
      |> Map.new()

    for {id, at} <- Repo.all(from a in Atlas, select: {a.id, a.updated_at}),
        do: {id, {at, jobs[id], contributions[id]}}
  end

  @count_key {__MODULE__, :count}

  @doc """
  How many parts wait for a person, for the volunteer page's button. `items/0`
  reads every atlas (seconds), so the count is shared and refreshed at most once
  a minute; while one caller refreshes it, the others get the last count.
  """
  def count do
    ttl = Application.get_env(:dpul_collections, :review_count_ttl_ms, 60_000)
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get(@count_key, nil) do
      # fresh
      {n, at, nil} when now - at < ttl ->
        n

      # another caller is refreshing it (a refresh older than the TTL was killed: take over)
      {n, _, started} when is_integer(started) and now - started < ttl ->
        n

      prev ->
        last = if prev, do: elem(prev, 0), else: 0
        :persistent_term.put(@count_key, {last, 0, now})
        n = length(items())
        :persistent_term.put(@count_key, {n, System.monotonic_time(:millisecond), nil})
        n
    end
  end

  def atlas_items(atlas_id) do
    atlas = Collab.atlas(atlas_id)
    latest = Collab.latest_by_part(atlas_id)
    parts = atlas["canvases"]
    placed = Enum.count(parts, &(&1["status"] == "ok"))
    share = if parts == [], do: 0, else: placed / length(parts)

    for {c, i} <- Enum.with_index(parts),
        c["status"] == "failed",
        not decided?(latest[{c["id"], c["part"]}]) do
      {tier, why} = tier(c)

      %{
        atlas_id: atlas["id"],
        atlas_label: atlas["label"],
        index: i,
        label: c["label"],
        service: c["service"],
        region: region(c["mask"]),
        tier: tier,
        why: why,
        names: names(c),
        ease: ease(tier, c, share)
      }
    end
  end

  defp decided?(nil), do: false
  defp decided?(contribution), do: Collab.human?(contribution)

  defp names(c), do: c["labels"] |> Enum.map(& &1["key"]) |> Enum.uniq() |> length()

  defp tier(%{"conflict" => true}), do: {2, "lands on top of another sheet"}

  defp tier(%{"transform" => t} = c) when is_map(t) do
    hits = "#{c["label_hits"] || 0} of #{names(c)} street names fit"

    if lines_up?(c),
      do: {1, hits <> " and the streets line up"},
      else: {3, hits <> ", but the streets don't line up"}
  end

  defp tier(c) do
    case names(c) do
      n when n >= 2 -> {3, "#{n} street names read, no placement found"}
      1 -> {4, "only 1 street name read"}
      _ -> {4, "no street names read (may not be a map)"}
    end
  end

  @doc """
  Whether the printed streets of a guess line up with the modern ones: its
  corridor contrast (how much better the modern streets fall in the printed
  street corridors here than at nearby placements). Every confident fit so far
  scores 0.13 or more; the wrong guesses seen score under 0.05.
  """
  def lines_up?(c), do: (c["contrast"] || 0) >= 0.1

  # share of the modern streets under the part that fall in its printed corridors
  defp in_corridors(%{"corridor" => [good, bad]}) when good + bad > 0, do: good / (good + bad)
  defp in_corridors(_), do: 0

  # higher is easier: within a tier, how well the printed streets line up first
  # (a guess that lines up is quick to confirm), then names agreeing and their
  # lead over the next-best spot; atlases mostly placed already break ties
  defp ease(tier, c, share) do
    hits = c["label_hits"] || 0
    lead = hits - (c["rival_hits"] || 0)
    lines = 300 * (c["contrast"] || 0) + 100 * in_corridors(c)
    within = lines + 4 * hits + 6 * lead + 2 * names(c)
    (5 - tier) * 1000 + min(within, 900) + 50 * share
  end

  # the part's bounding box as an IIIF region, for a thumbnail
  defp region([_ | _] = mask) do
    {xs, ys} = mask |> Enum.map(fn [x, y] -> {x, y} end) |> Enum.unzip()
    {x0, y0} = {Enum.min(xs), Enum.min(ys)}
    Enum.map_join([x0, y0, Enum.max(xs) - x0, Enum.max(ys) - y0], ",", &round/1)
  end

  defp region(_), do: "full"
end
