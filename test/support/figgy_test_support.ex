defmodule FiggyTestSupport do
  import Ecto.Query, warn: false
  alias DpulCollections.IndexingPipeline.{ResourceMarker, FiggyResource}
  alias DpulCollections.FiggyRepo

  # @spec markers :: {ProcessorMarker.marker(), ProcessorMarker.marker(), ProcessorMarker.marker()}
  # These are the first three known resource markers in the test database.
  # They're here so that if they change, we don't have to change them in the
  # whole test suite.
  def markers do
    marker1 = %ResourceMarker{
      timestamp: ~U[2018-03-09 20:19:33.414040Z],
      id: "3cb7627b-defc-401b-9959-42ebc4488f74"
    }

    marker2 = %ResourceMarker{
      timestamp: ~U[2018-03-09 20:19:34.465203Z],
      id: "69990556-434c-476a-9043-bbf9a1bda5a4"
    }

    marker3 = %ResourceMarker{
      timestamp: ~U[2018-03-09 20:19:34.486004Z],
      id: "47276197-e223-471c-99d7-405c5f6c5285"
    }

    {marker1, marker2, marker3}
  end

  # Get the last marker from the figgy repo.
  def last_marker do
    query =
      from r in FiggyResource,
        limit: 1,
        order_by: [desc: r.updated_at, desc: r.id]

    FiggyRepo.all(query) |> hd |> ResourceMarker.from()
  end
end
