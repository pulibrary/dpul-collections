defmodule DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarkerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker

  describe "marker comparison" do
    test "sorts markers appropriately" do
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers()

      assert Enum.sort([marker1, marker3, marker2], CacheEntryMarker) == [
               marker1,
               marker2,
               marker3
             ]

      assert CacheEntryMarker.compare(marker1, marker1) == :eq
      assert CacheEntryMarker.compare(marker2, marker1) == :gt
      assert CacheEntryMarker.compare(marker1, marker2) == :lt

      fabricated_marker = %CacheEntryMarker{
        timestamp: marker1.timestamp,
        id: "00000000-0000-0000-0000-000000000000"
      }

      assert CacheEntryMarker.compare(fabricated_marker, marker1) == :lt
      assert CacheEntryMarker.compare(marker1, fabricated_marker) == :gt
    end
  end
end
