defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.{FiggyHydrator, FiggyResource, HydrationCacheEntry}

  describe "FiggyHydrator" do
    test "handle_message/3 only writes EphemeraFolders to the HydrationCache" do
      folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %FiggyResource{
          id: "3cb7627b-defc-401b-9959-42ebc4488f74",
          updated_at: ~U[2018-03-09 20:19:33.414040Z],
          internal_resource: "EphemeraFolder"
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

      FiggyHydrator.handle_message(nil, folder_message, %{cache_version: 0})
      FiggyHydrator.handle_message(nil, scanned_resource_message, %{cache_version: 0})

      entry_count = Repo.aggregate(HydrationCacheEntry, :count)
      assert entry_count == 1
    end
  end
end
