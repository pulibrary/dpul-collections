defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyProducer

  describe "FiggyProducer" do
    test "handle_demand/2 returns figgy resources" do
      initial_state = %{last_queried_marker: nil, pulled_records: [], acked_records: []}
      {:noreply, records, _state} = FiggyProducer.handle_demand(1, initial_state)
      assert Enum.at(records, 0).id == "3cb7627b-defc-401b-9959-42ebc4488f74"

    end
  end
end
