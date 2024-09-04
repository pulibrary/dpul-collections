defmodule FiggyTestFixtures do
  alias DpulCollections.IndexingPipeline.{ResourceMarker, HydrationCacheEntryMarker}
  alias DpulCollections.IndexingPipeline

  # TODO: Rename module to TestFixtures

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

  # TODO: These should be EphemeraFolders and EphemeraTerms where the terms are
  # associtated with the folder.
  def hydration_cache_markers(cache_version \\ 0) do
    {:ok, entry1} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
        source_cache_order: ~U[2018-03-09 20:19:33.414040Z],
        data: %{
          "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
          "internal_resource" => "EphemeraFolder",
          "metadata" => %{"title" => ["test title 1"]}
        }
      })

    {:ok, entry2} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "69990556-434c-476a-9043-bbf9a1bda5a4",
        source_cache_order: ~U[2018-03-09 20:19:34.465203Z],
        data: %{
          "id" => "69990556-434c-476a-9043-bbf9a1bda5a4",
          "internal_resource" => "EphemeraFolder",
          "metadata" => %{"title" => ["test title 2"]}
        }
      })

    {:ok, entry3} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "47276197-e223-471c-99d7-405c5f6c5285",
        source_cache_order: ~U[2018-03-09 20:19:34.486004Z],
        data: %{
          "id" => "47276197-e223-471c-99d7-405c5f6c5285",
          "internal_resource" => "EphemeraFolder",
          "metadata" => %{"title" => ["test title"]}
        }
      })

    marker1 = %HydrationCacheEntryMarker{
      timestamp: entry1.source_cache_order,
      id: entry1.record_id
    }

    marker2 = %HydrationCacheEntryMarker{
      timestamp: entry2.source_cache_order,
      id: entry2.record_id
    }

    marker3 = %HydrationCacheEntryMarker{
      timestamp: entry3.source_cache_order,
      id: entry3.record_id
    }

    {marker1, marker2, marker3}
  end
end
