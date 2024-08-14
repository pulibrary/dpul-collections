defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  alias DpulCollections.IndexingPipeline.FiggyHydrator
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.{FiggyProducer, FiggyResource}
  alias DpulCollections.IndexingPipeline

  describe "FiggyProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      initial_state = FiggyProducer.init(0) |> elem(1)
      {:noreply, messages, new_state} = FiggyProducer.handle_demand(2, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)

      assert ids == [
               "3cb7627b-defc-401b-9959-42ebc4488f74",
               "69990556-434c-476a-9043-bbf9a1bda5a4"
             ]

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

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids = ["47276197-e223-471c-99d7-405c5f6c5285"]

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

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids = ["47276197-e223-471c-99d7-405c5f6c5285"]

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

    test "handle_info/2 with figgy producer ack, acknowledging first and third record" do
      start_state = %{
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
    end
  end
end
