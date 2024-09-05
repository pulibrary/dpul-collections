defmodule DpulCollections.IndexingPipeline.Figgy.TransformationCacheEntryMarkerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy.TransformationCacheEntryMarker

  describe "marker comparison" do
    test "sorts markers appropriately" do
      {marker1, marker2, marker3} = FiggyTestFixtures.transformation_cache_markers()

      assert Enum.sort([marker1, marker3, marker2], TransformationCacheEntryMarker) == [
               marker1,
               marker2,
               marker3
             ]

      assert TransformationCacheEntryMarker.compare(marker1, marker1) == :eq
      assert TransformationCacheEntryMarker.compare(marker2, marker1) == :gt
      assert TransformationCacheEntryMarker.compare(marker1, marker2) == :lt

      fabricated_marker = %TransformationCacheEntryMarker{
        timestamp: marker1.timestamp,
        id: "00000000-0000-0000-0000-000000000000"
      }

      assert TransformationCacheEntryMarker.compare(fabricated_marker, marker1) == :lt
      assert TransformationCacheEntryMarker.compare(marker1, fabricated_marker) == :gt
    end
  end
end
