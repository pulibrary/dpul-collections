defmodule DpulCollections.IndexingPipeline.DatabaseProducerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline

  describe "DatabaseProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns hydration cache entries" do
      {marker1, marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      {:noreply, messages, new_state} =
        DatabaseProducer.handle_demand(2, initial_state)

      ids =
        Enum.map(messages, fn %Broadway.Message{data: %Figgy.HydrationCacheEntry{record_id: id}} ->
          id
        end)

      assert ids == [marker1.id, marker2.id]

      assert %{
               last_queried_marker: ^marker2,
               pulled_records: [
                 ^marker1,
                 ^marker2
               ],
               acked_records: [],
               cache_version: 0,
               stored_demand: 0
             } = new_state
    end

    test "handle_demand/2 with consecutive state returns a new record" do
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers()

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker2,
          pulled_records: [
            marker1,
            marker2
          ],
          acked_records: [],
          cache_version: 0,
          stored_demand: 0
        })

      {:noreply, messages, new_state} =
        DatabaseProducer.handle_demand(1, initial_state)

      ids =
        Enum.map(messages, fn %Broadway.Message{data: %Figgy.HydrationCacheEntry{record_id: id}} ->
          id
        end)

      assert ids == [marker3.id]

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [
                 ^marker1,
                 ^marker2,
                 ^marker3
               ],
               acked_records: [],
               cache_version: 0,
               stored_demand: 0
             } = new_state
    end

    test "handle_demand/2 when the query returns no records" do
      {_marker1, _marker2, marker3} = FiggyTestFixtures.hydration_cache_markers()

      # Move last_queried marker to a marker 200 years in the future.
      marker3_cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd

      fabricated_marker = %CacheEntryMarker{
        timestamp: DateTime.add(marker3_cache_entry.cache_order, 356 * 10, :day),
        id: marker3.id
      }

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: fabricated_marker,
          pulled_records: [],
          acked_records: [],
          cache_version: 0,
          stored_demand: 0
        })

      {:noreply, messages, new_state} =
        DatabaseProducer.handle_demand(1, initial_state)

      assert messages == []

      assert %{
               last_queried_marker: ^fabricated_marker,
               pulled_records: [],
               acked_records: [],
               cache_version: 0,
               stored_demand: 1
             } = new_state
    end

    test "handle_info/2 with database producer ack, acknowledging first and third record" do
      cache_version = 1
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers(cache_version)

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker3,
          pulled_records: [
            marker1,
            marker2,
            marker3
          ],
          acked_records: [],
          cache_version: cache_version,
          stored_demand: 0
        })

      acked_hydration_cache_markers =
        [
          marker1,
          marker3
        ]
        |> Enum.sort()

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, acked_hydration_cache_markers},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [
                 ^marker2,
                 ^marker3
               ],
               acked_records: [
                 ^marker3
               ],
               cache_version: ^cache_version,
               stored_demand: 0
             } = new_state

      processor_marker =
        IndexingPipeline.get_processor_marker!("figgy_transformer", cache_version)

      assert marker1 == %CacheEntryMarker{
               timestamp: processor_marker.cache_location,
               id: processor_marker.cache_record_id
             }

      initial_state = new_state
      acked_hydration_cache_markers = [marker2]

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, acked_hydration_cache_markers},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [],
               acked_records: [],
               cache_version: ^cache_version,
               stored_demand: 0
             } = new_state

      processor_marker =
        IndexingPipeline.get_processor_marker!("figgy_transformer", cache_version)

      assert marker3 == %CacheEntryMarker{
               timestamp: processor_marker.cache_location,
               id: processor_marker.cache_record_id
             }
    end

    test "handle_info/2 with database producer ack, nothing to acknowledge" do
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers(1)

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker3,
          pulled_records: [
            marker1,
            marker2,
            marker3
          ],
          acked_records: [],
          cache_version: 1,
          stored_demand: 0
        })

      acked_hydration_cache_markers =
        [
          marker2
        ]
        |> Enum.sort()

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, acked_hydration_cache_markers},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [
                 ^marker1,
                 ^marker2,
                 ^marker3
               ],
               acked_records: [
                 ^marker2
               ],
               cache_version: 1,
               stored_demand: 0
             } = new_state

      processor_marker = IndexingPipeline.get_processor_marker!("figgy_transformer", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with database producer ack, empty pulled_records" do
      {marker1, _marker2, marker3} = FiggyTestFixtures.hydration_cache_markers(1)

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker3,
          pulled_records: [],
          acked_records: [],
          cache_version: 1,
          stored_demand: 0
        })

      acked_hydration_cache_markers =
        [
          marker1
        ]
        |> Enum.sort()

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, acked_hydration_cache_markers},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [],
               acked_records: [],
               cache_version: 1,
               stored_demand: 0
             } = new_state

      processor_marker = IndexingPipeline.get_processor_marker!("figgy_transformer", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with database producer ack, duplicate ack records" do
      {marker1, marker2, marker3} = FiggyTestFixtures.hydration_cache_markers(1)

      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker3,
          pulled_records: [
            marker1,
            marker2
          ],
          acked_records: [
            marker2
          ],
          cache_version: 1,
          stored_demand: 0
        })

      acked_hydration_cache_markers =
        [
          marker2
        ]
        |> Enum.sort()

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, acked_hydration_cache_markers},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker3,
               pulled_records: [
                 ^marker1,
                 ^marker2
               ],
               acked_records: [
                 ^marker2
               ],
               cache_version: 1,
               stored_demand: 0
             } = new_state

      processor_marker = IndexingPipeline.get_processor_marker!("figgy_transformer", 1)
      assert processor_marker == nil
    end

    test "handle_info/2 with database producer ack, acking after crash and respawn" do
      {marker1, marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers(1)

      # Producer sent out marker1 then crashed, started again, then sent out
      # marker1 and marker2.
      # The consumer has marker1, marker1, and marker2 to process.
      {:producer, initial_state} = DatabaseProducer.init({Figgy.TransformationProducerSource, 0})

      initial_state =
        initial_state
        |> Map.merge(%{
          last_queried_marker: marker2,
          pulled_records: [
            marker1,
            marker2
          ],
          acked_records: [],
          cache_version: 1,
          stored_demand: 0
        })

      first_ack =
        [
          marker1
        ]

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, first_ack},
          initial_state
        )

      assert %{
               last_queried_marker: ^marker2,
               pulled_records: [
                 ^marker2
               ],
               acked_records: [],
               cache_version: 1,
               stored_demand: 0
             } = new_state

      second_ack =
        [
          marker1,
          marker2
        ]

      {:noreply, [], new_state} =
        DatabaseProducer.handle_info(
          {:ack, :database_producer_ack, second_ack},
          new_state
        )

      assert %{
               last_queried_marker: ^marker2,
               pulled_records: [],
               acked_records: [],
               cache_version: 1,
               stored_demand: 0
             } = new_state

      processor_marker =
        IndexingPipeline.get_processor_marker!("figgy_transformer", 1)
        |> CacheEntryMarker.from()

      assert processor_marker == marker2
    end

    test ".handle_info(:check_for_updates) with no stored demand" do
      assert DatabaseProducer.handle_info(:check_for_updates, %{stored_demand: 0}) ==
               {:noreply, [], %{stored_demand: 0}}
    end
  end
end
