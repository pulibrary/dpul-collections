defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
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
          acked_records: [],
          cache_version: 0
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
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids == ["47276197-e223-471c-99d7-405c5f6c5285"]

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
          acked_records: [],
          cache_version: 0
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
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids == ["47276197-e223-471c-99d7-405c5f6c5285"]

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
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 when the query returns no records" do
      initial_state =
        %{
          last_queried_marker:
            {~U[2200-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [],
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      assert messages == []

      expected_state =
        %{
          last_queried_marker:
            {~U[2200-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [],
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    # Returns fixture markers for handle_info tests.
    defp markers do
      marker1 = {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"}
      marker2 = {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
      marker3 = {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"}
      { marker1, marker2, marker3 }
    end

    test "handle_info/2 with figgy producer ack, acknowledging first and third record" do
      { marker1, marker2, marker3 } = markers()

      initial_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker1,
          marker2,
          marker3
        ],
        acked_records: [],
        cache_version: 1
      }

      acked_markers =
        [
          marker1,
          marker3
        ]
        |> Enum.sort()

      expected_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker2,
          marker3
        ],
        acked_records: [
          marker3
        ],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_hydrator_marker(1)

      assert marker1 == {processor_marker.cache_location, processor_marker.cache_record_id}

      initial_state = new_state
      acked_markers = [marker2]

      expected_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [],
        acked_records: [],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state

      processor_marker = IndexingPipeline.get_hydrator_marker(1)
      assert marker3 == {processor_marker.cache_location, processor_marker.cache_record_id}

      # Edge cases to test:
      # 1. Something breaks, an already acked_record is acked again, resulting
      #    in duplicates in acked_records
    end

    test "handle_info/2 with figgy producer ack, nothing to acknowledge" do
      { marker1, marker2, marker3 } = markers()

      initial_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker1,
          marker2,
          marker3
        ],
        acked_records: [],
        cache_version: 1
      }

      acked_markers =
        [
          marker2
        ]
        |> Enum.sort()

      expected_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker1,
          marker2,
          marker3
        ],
        acked_records: [
          marker2
        ],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_hydrator_marker(1)
      assert processor_marker == nil
    end

    test "handle_info/2 with figgy producer ack, empty pulled_records" do
      { marker1, _marker2, _marker3 } = markers()

      initial_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [],
        acked_records: [],
        cache_version: 1
      }

      acked_markers =
        [
          marker1
        ]
        |> Enum.sort()

      expected_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [],
        acked_records: [],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_hydrator_marker(1)
      assert processor_marker == nil
    end

    test "handle_info/2 with figgy producer ack, duplicate ack records" do
      { marker1, marker2, _marker3 } = markers()

      initial_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker1,
          marker2
        ],
        acked_records: [
          marker2
        ],
        cache_version: 1
      }

      acked_markers =
        [
          marker2
        ]
        |> Enum.sort()

      expected_state = %{
        last_queried_marker:
          {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
        pulled_records: [
          marker1,
          marker2
        ],
        acked_records: [
          marker2
        ],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_hydrator_marker(1)
      assert processor_marker == nil
    end
  end
end
