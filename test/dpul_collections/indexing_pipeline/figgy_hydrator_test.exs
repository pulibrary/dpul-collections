defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyHydrator

  describe "FiggyHydrator" do
    test "handle_message/3" do
      ref = Broadway.test_message(FiggyHydrator, 1)
      assert_receive {:ack, ^ref, [%{data: 1}], []}

      # list_hydration_cache_entries
    end
  end
end
