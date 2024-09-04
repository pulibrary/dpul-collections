defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntryMarkerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntryMarker

  describe "marker comparison" do
    test "sorts markers appropriately" do
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers()

      assert Enum.sort([marker1, marker3, marker2], HydrationCacheEntryMarker) == [
               marker1,
               marker2,
               marker3
             ]

      assert HydrationCacheEntryMarker.compare(marker1, marker1) == :eq
      assert HydrationCacheEntryMarker.compare(marker2, marker1) == :gt
      assert HydrationCacheEntryMarker.compare(marker1, marker2) == :lt

      fabricated_marker = %HydrationCacheEntryMarker{
        timestamp: marker1.timestamp,
        id: "00000000-0000-0000-0000-000000000000"
      }

      assert HydrationCacheEntryMarker.compare(fabricated_marker, marker1) == :lt
      assert HydrationCacheEntryMarker.compare(marker1, fabricated_marker) == :gt
    end
  end
end
