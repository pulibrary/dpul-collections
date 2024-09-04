defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
  alias DpulCollections.IndexingPipeline.Figgy.Hydrator
  alias DpulCollections.IndexingPipeline.FiggyResource

  describe "Figgy.Hydrator" do
    test "handle_message/3 only writes EphemeraFolders and EphemeraTerms to the HydrationCache" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %FiggyResource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder"
        }
      }

      ephemera_term_message = %Broadway.Message{
        acknowledger: nil,
        data: %FiggyResource{
          id: "3cb7627b-defc-401b-9959-42ebc4488f74",
          updated_at: ~U[2018-03-09 20:19:33.414040Z],
          internal_resource: "EphemeraTerm"
        }
      }

      scanned_resource_message = %Broadway.Message{
        acknowledger: nil,
        data: %FiggyResource{
          id: "69990556-434c-476a-9043-bbf9a1bda5a4",
          updated_at: ~U[2018-03-09 20:19:34.465203Z],
          internal_resource: "ScannedResource"
        }
      }

      Hydrator.handle_message(nil, ephemera_folder_message, %{cache_version: 0})
      Hydrator.handle_message(nil, ephemera_term_message, %{cache_version: 0})
      Hydrator.handle_message(nil, scanned_resource_message, %{cache_version: 0})

      entry_count = Repo.aggregate(HydrationCacheEntry, :count)
      assert entry_count == 2
    end
  end
end
