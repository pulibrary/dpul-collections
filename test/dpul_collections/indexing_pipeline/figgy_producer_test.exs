defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyProducer

  describe "FiggyProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      initial_state = %{last_queried_marker: nil}
      {:noreply, records, new_state} = FiggyProducer.handle_demand(2, initial_state)
      assert Enum.at(records, 0).id == "3cb7627b-defc-401b-9959-42ebc4488f74"
      assert Enum.at(records, 1).id == "69990556-434c-476a-9043-bbf9a1bda5a4"

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [
            {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"},
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 with consecutive state returns a new record" do
      initial_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [
            {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"},
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
          ],
          acked_records: []
        }

      {:noreply, records, new_state} = FiggyProducer.handle_demand(1, initial_state)
      record1 = Enum.at(records, 0)
      # record2 = Enum.at(records, 1)
      # we will get the same record again because we're doing >= on the
      # last_queried_marker date stamp, to make sure
      # we don't miss any records.
      # assert record1.id == "69990556-434c-476a-9043-bbf9a1bda5a4"
      assert record1.id == "47276197-e223-471c-99d7-405c5f6c5285"

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {
              ~U[2018-03-09 20:19:33.414040Z],
              "3cb7627b-defc-401b-9959-42ebc4488f74"
            },
            {
              ~U[2018-03-09 20:19:34.465203Z],
              "69990556-434c-476a-9043-bbf9a1bda5a4"
            },
            {
              ~U[2018-03-09 20:19:34.486004Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            }
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 when the marker record has been updated" do
      initial_state =
        %{
          # This is a manufactured marker.
          # This timestamp is set to be right before the actual record updated_at.
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465204Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {~U[2018-03-09 20:19:34.465204Z], "47276197-e223-471c-99d7-405c5f6c5285"}
          ],
          acked_records: []
        }

      {:noreply, records, new_state} = FiggyProducer.handle_demand(1, initial_state)
      record1 = Enum.at(records, 0)

      assert record1.id == "47276197-e223-471c-99d7-405c5f6c5285"

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {
              ~U[2018-03-09 20:19:34.465204Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            },
            {
              ~U[2018-03-09 20:19:34.486004Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            }
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    defmodule TestConsumer do
      def start_link(producer) do
        GenStage.start_link(__MODULE__, {producer, self()})
      end

      def init({producer, owner}) do
        {:consumer, owner, subscribe_to: [producer]}
      end

      def handle_events(events, _from, owner) do
        send(owner, {:received, events})
        {:noreply, [], owner}
      end
    end

    test "check the results" do
      {:ok, stage} = FiggyProducer.start_link()
      {:ok, _cons} = TestConsumer.start_link(stage)

      assert_receive {:received, _records}

      # The test consumer will also stop, since it is subscribed to the stage
      GenStage.stop(stage)
    end
  end
end
