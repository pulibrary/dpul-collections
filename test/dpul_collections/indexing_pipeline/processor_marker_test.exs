defmodule DpulCollections.IndexingPipeline.ProcessorMarkerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.ProcessorMarker

  describe "marker comparison" do
    test "sorts markers appropriately" do
      {marker1, marker2, marker3} = FiggyTestSupport.markers()
      assert Enum.sort([marker1, marker3, marker2], ProcessorMarker) == [marker1, marker2, marker3]

      assert ProcessorMarker.compare(marker1, marker1) == :eq
      assert ProcessorMarker.compare(marker2, marker1) == :gt
      assert ProcessorMarker.compare(marker1, marker2) == :lt
      fabricated_marker = { elem(marker1, 0), "00000000-0000-0000-0000-000000000000" }
      assert ProcessorMarker.compare(fabricated_marker, marker1) == :lt
      assert ProcessorMarker.compare(marker1, fabricated_marker) == :gt
    end
  end
end
