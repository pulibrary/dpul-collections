defmodule FiggyTestSupport do
  import Ecto.Query, warn: false

  alias DpulCollections.IndexingPipeline.Figgy

  alias DpulCollections.FiggyRepo
  alias DpulCollections.Repo

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
