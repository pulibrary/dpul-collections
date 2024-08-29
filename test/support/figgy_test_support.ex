defmodule FiggyTestSupport do
  import Ecto.Query, warn: false
  alias DpulCollections.IndexingPipeline.{ResourceMarker, FiggyResource}
  alias DpulCollections.FiggyRepo

  # Get the last marker from the figgy repo.
  def last_marker do
    query =
      from r in FiggyResource,
        limit: 1,
        order_by: [desc: r.updated_at, desc: r.id]

    FiggyRepo.all(query) |> hd |> ResourceMarker.from()
  end

  def included_resource_count do
    query =
      from r in FiggyResource,
        where: r.internal_resource == "EphemeraFolder" or r.internal_resource == "EphemeraTerm"

    FiggyRepo.aggregate(query, :count)
  end
end
