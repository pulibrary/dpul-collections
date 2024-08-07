defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyHydrator
  alias DpulCollections.IndexingPipeline

  describe "FiggyHydrator" do
    test "handle_message/3" do
      ref = Broadway.test_message(FiggyHydrator, 1)
      assert_receive {:ack, ^ref, [%{data: 1}], []}

      cache_entry = IndexingPipeline.list_hydration_cache_entries |> hd
      assert cache_entry.data == 1
    end
  end
end
