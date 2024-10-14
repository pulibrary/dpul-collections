defmodule FiggyTestSupport do
  import Ecto.Query, warn: false

  alias DpulCollections.IndexingPipeline.Figgy

  alias DpulCollections.FiggyRepo

  def ephemera_folder_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder"

    FiggyRepo.aggregate(query, :count)
  end
end
