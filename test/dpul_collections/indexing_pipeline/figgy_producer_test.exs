defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.{FiggyProducer, FiggyResource}
  alias DpulCollections.IndexingPipeline

  describe "FiggyProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      {marker1, marker2, _marker3} = FiggyTestSupport.markers()
      {:producer, initial_state} = FiggyProducer.init(0)
      {:noreply, messages, new_state} = FiggyProducer.handle_demand(2, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)

      assert ids == [elem(marker1, 1), elem(marker2, 1)]

      expected_state =
        %{
          last_queried_marker: marker2,
          pulled_records: [
            marker1,
            marker2
          ],
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 with consecutive state returns a new record" do
      {marker1, marker2, marker3} = FiggyTestSupport.markers()

      initial_state =
        %{
          last_queried_marker: marker2,
          pulled_records: [
            marker1,
            marker2
          ],
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids == [elem(marker3, 1)]

      expected_state =
        %{
          last_queried_marker: marker3,
          pulled_records: [
            marker1,
            marker2,
            marker3
          ],
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 when the marker record has been updated" do
      {_marker1, marker2, marker3} = FiggyTestSupport.markers()
      fabricated_marker = {DateTime.add(elem(marker2, 0), 1, :microsecond), elem(marker3, 1)}

      initial_state =
        %{
          # This is a manufactured marker.
          # This timestamp is set to be right before the actual record updated_at.
          last_queried_marker: fabricated_marker,
          pulled_records: [
            fabricated_marker
          ],
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids == [elem(marker3, 1)]

      expected_state =
        %{
          last_queried_marker: marker3,
          pulled_records: [
            fabricated_marker,
            marker3
          ],
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 when the query returns no records" do
      {marker1, marker2, marker3} = FiggyTestSupport.markers()
      # Move last_queried marker to a marker 200 years in the future.
      fabricated_marker = {DateTime.add(elem(marker3, 0), 356 * 10, :day), elem(marker3, 1)}

      initial_state =
        %{
          last_queried_marker: fabricated_marker,
          pulled_records: [],
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      assert messages == []

      expected_state =
        %{
          last_queried_marker: fabricated_marker,
          pulled_records: [],
          acked_records: [],
          cache_version: 0
        }

      assert new_state == expected_state
    end

    test "handle_info/2 with figgy producer ack, acknowledging first and third record" do
      {marker1, marker2, marker3} = FiggyTestSupport.markers()

      initial_state = %{
        last_queried_marker: marker3,
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
        last_queried_marker: marker3,
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
        last_queried_marker: marker3,
        pulled_records: [],
        acked_records: [],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        FiggyProducer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state

      processor_marker = IndexingPipeline.get_hydrator_marker(1)
      assert marker3 == {processor_marker.cache_location, processor_marker.cache_record_id}
    end

    test "handle_info/2 with figgy producer ack, nothing to acknowledge" do
      {marker1, marker2, marker3} = FiggyTestSupport.markers()

      initial_state = %{
        last_queried_marker: marker3,
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
        last_queried_marker: marker3,
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
      {marker1, _marker2, marker3} = FiggyTestSupport.markers()

      initial_state = %{
        last_queried_marker: marker3,
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
        last_queried_marker: marker3,
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
      {marker1, marker2, marker3} = FiggyTestSupport.markers()

      initial_state = %{
        last_queried_marker: marker3,
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
        last_queried_marker: marker3,
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
