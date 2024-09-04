defmodule FiggyTestSupport do
  import Ecto.Query, warn: false

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.ResourceMarker

  alias DpulCollections.FiggyRepo
  alias DpulCollections.Repo

  # Get the last marker from the figgy repo.
  def last_figgy_resource_marker do
    query =
      from r in Figgy.Resource,
        limit: 1,
        order_by: [desc: r.updated_at, desc: r.id]

    FiggyRepo.all(query) |> hd |> ResourceMarker.from()
  end

  def last_hydration_cache_entry_marker do
    query =
      from r in Figgy.HydrationCacheEntry,
        limit: 1,
        order_by: [desc: r.source_cache_order, desc: r.id]

    Repo.all(query) |> hd |> Figgy.HydrationCacheEntryMarker.from()
  end

  def total_resource_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder" or r.internal_resource == "EphemeraTerm"

    FiggyRepo.aggregate(query, :count)
  end

  def ephemera_folder_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder"

    FiggyRepo.aggregate(query, :count)
  end
end
