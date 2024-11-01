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

  describe ".from/1" do
    test "it can take a broadway message that has a marker and a handled_data key" do
      {marker1, _, _} = FiggyTestFixtures.hydration_cache_markers()
      message = %Broadway.Message{acknowledger: nil, data: %{marker: marker1, handled_data: %{}}}

      assert CacheEntryMarker.from(message) == marker1
    end

    test "it returns a marker if given one" do
      {marker1, _, _} = FiggyTestFixtures.hydration_cache_markers()
      assert CacheEntryMarker.from(marker1) == marker1
    end
  end
end
