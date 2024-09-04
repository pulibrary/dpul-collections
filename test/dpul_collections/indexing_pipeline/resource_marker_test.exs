defmodule DpulCollections.IndexingPipeline.ResourceMarkerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy

  describe "marker comparison" do
    test "sorts markers appropriately" do
      {marker1, marker2, marker3} = FiggyTestFixtures.markers()

      assert Enum.sort([marker1, marker3, marker2], Figgy.ResourceMarker) == [
               marker1,
               marker2,
               marker3
             ]

      assert Figgy.ResourceMarker.compare(marker1, marker1) == :eq
      assert Figgy.ResourceMarker.compare(marker2, marker1) == :gt
      assert Figgy.ResourceMarker.compare(marker1, marker2) == :lt

      fabricated_marker = %Figgy.ResourceMarker{
        timestamp: marker1.timestamp,
        id: "00000000-0000-0000-0000-000000000000"
      }

      assert Figgy.ResourceMarker.compare(fabricated_marker, marker1) == :lt
      assert Figgy.ResourceMarker.compare(marker1, fabricated_marker) == :gt
    end
  end
end
