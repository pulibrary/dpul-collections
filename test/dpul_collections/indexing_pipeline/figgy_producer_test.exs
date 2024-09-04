defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline

  describe "Figgy.Producer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      {marker1, marker2, _marker3} = FiggyTestFixtures.markers()
      {:producer, initial_state} = Figgy.Producer.init(0)
      {:noreply, messages, new_state} = Figgy.Producer.handle_demand(2, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %Figgy.Resource{id: id}} -> id end)

      assert ids == [marker1.id, marker2.id]

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
      {marker1, marker2, marker3} = FiggyTestFixtures.markers()

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

      {:noreply, messages, new_state} = Figgy.Producer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %Figgy.Resource{id: id}} -> id end)
      assert ids == [marker3.id]

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
      {_marker1, marker2, marker3} = FiggyTestFixtures.markers()

      fabricated_marker = %Figgy.ResourceMarker{
        timestamp: DateTime.add(marker2.timestamp, 1, :microsecond),
        id: marker3.id
      }

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

      {:noreply, messages, new_state} = Figgy.Producer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %Figgy.Resource{id: id}} -> id end)
      assert ids == [marker3.id]

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
      {_marker1, _marker2, marker3} = FiggyTestFixtures.markers()
      # Move last_queried marker to a marker 200 years in the future.
      fabricated_marker = %Figgy.ResourceMarker{
        timestamp: DateTime.add(marker3.timestamp, 356 * 10, :day),
        id: marker3.id
      }

      initial_state =
        %{
          last_queried_marker: fabricated_marker,
          pulled_records: [],
          acked_records: [],
          cache_version: 0
        }

      {:noreply, messages, new_state} = Figgy.Producer.handle_demand(1, initial_state)

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
      {marker1, marker2, marker3} = FiggyTestFixtures.markers()
      cache_version = 1

      initial_state = %{
        last_queried_marker: marker3,
        pulled_records: [
          marker1,
          marker2,
          marker3
        ],
        acked_records: [],
        cache_version: cache_version
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
        cache_version: cache_version
      }

      {:noreply, [], new_state} =
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_processor_marker!("hydrator", cache_version)

      assert marker1 == %Figgy.ResourceMarker{
               timestamp: processor_marker.cache_location,
               id: processor_marker.cache_record_id
             }

      initial_state = new_state
      acked_markers = [marker2]

      expected_state = %{
        last_queried_marker: marker3,
        pulled_records: [],
        acked_records: [],
        cache_version: cache_version
      }

      {:noreply, [], new_state} =
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state

      processor_marker = IndexingPipeline.get_processor_marker!("hydrator", cache_version)

      assert marker3 == %Figgy.ResourceMarker{
               timestamp: processor_marker.cache_location,
               id: processor_marker.cache_record_id
             }
    end

    test "handle_info/2 with figgy producer ack, nothing to acknowledge" do
      {marker1, marker2, marker3} = FiggyTestFixtures.markers()

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
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_processor_marker!("hydrator", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with figgy producer ack, empty pulled_records" do
      {marker1, _marker2, marker3} = FiggyTestFixtures.markers()

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
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_processor_marker!("hydrator", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with figgy producer ack, duplicate ack records" do
      {marker1, marker2, marker3} = FiggyTestFixtures.markers()

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
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, acked_markers}, initial_state)

      assert new_state == expected_state
      processor_marker = IndexingPipeline.get_processor_marker!("hydrator", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with figgy producer ack, acking after crash and respawn" do
      {marker1, marker2, _marker3} = FiggyTestFixtures.markers()

      # Figgy.Producer sent out marker1 then crashed, started again, then sent out
      # marker1 and marker2.
      # The consumer has marker1, marker1, and marker2 to process.
      initial_state = %{
        last_queried_marker: marker2,
        pulled_records: [
          marker1,
          marker2
        ],
        acked_records: [],
        cache_version: 1
      }

      first_ack =
        [
          marker1
        ]

      expected_state = %{
        last_queried_marker: marker2,
        pulled_records: [
          marker2
        ],
        acked_records: [],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, first_ack}, initial_state)

      assert new_state == expected_state

      second_ack =
        [
          marker1,
          marker2
        ]

      expected_state = %{
        last_queried_marker: marker2,
        pulled_records: [],
        acked_records: [],
        cache_version: 1
      }

      {:noreply, [], new_state} =
        Figgy.Producer.handle_info({:ack, :figgy_producer_ack, second_ack}, new_state)

      assert new_state == expected_state

      processor_marker =
        IndexingPipeline.get_processor_marker!("hydrator", 1) |> Figgy.ResourceMarker.from()

      assert processor_marker == marker2
    end
  end
end
