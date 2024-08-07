defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyHydrator

  describe "FiggyHydrator" do
    # TODO: Look at https://hexdocs.pm/broadway/Broadway.html#module-testing
    test "handle_message/3" do
      ref = Broadway.test_message(FiggyHydrator, 1)
      assert_receive {:ack, ^ref, [%{data: 1}], []}
    end
  end
end
