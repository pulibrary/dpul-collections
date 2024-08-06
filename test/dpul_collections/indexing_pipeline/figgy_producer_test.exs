defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyProducer

  describe "FiggyProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      initial_state = %{last_queried_marker: nil}
      {:noreply, records, new_state} = FiggyProducer.handle_demand(2, initial_state)
      assert Enum.at(records, 0).id == "3cb7627b-defc-401b-9959-42ebc4488f74"

      last_record = Enum.at(records, -1)
      expected_state =
        %{
          last_queried_marker: {last_record.updated_at, last_record.id},
          pulled_records: Enum.map(records, fn r -> {r.updated_at, r.id} end),
          acked_records: []
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 with consecutive state and demand > 1 returns figgy resources" do
      initial_state =
        %{
          last_queried_marker: ~U[2018-03-09 20:19:33Z],
          pulled_records: ["3cb7627b-defc-401b-9959-42ebc4488f74"],
          acked_records: []
        }

      {:noreply, records, new_state} = FiggyProducer.handle_demand(2, initial_state)
      record1 = Enum.at(records, 0)
      record2 = Enum.at(records, 1)
      # we will get the same record again because we're doing >= on the
      # last_queried_marker date stamp, to make sure
      # we don't miss any records.
      assert record1.id == "3cb7627b-defc-401b-9959-42ebc4488f74"
      assert record2.id == "69990556-434c-476a-9043-bbf9a1bda5a4"

      # TODO: update markers
      expected_state =
        %{
          last_queried_marker: Enum.at(records, -1).updated_at,
          pulled_records: Enum.map(records, fn r -> r.id end),
          acked_records: []
        }

      assert new_state == expected_state
    end
  end
end
