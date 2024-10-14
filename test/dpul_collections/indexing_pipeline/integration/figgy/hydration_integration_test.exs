defmodule DpulCollections.IndexingPipeline.Figgy.HyrdationIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  alias DpulCollections.IndexingPipeline

  def jump_processor_to_ephemera_folder(cache_version \\ 0) do
    {marker1, _, _} = FiggyTestFixtures.markers()
    # Write the hydrator right behind an EphemeraFolder, since there are
    # DeletionMarkers in front of EphemeraFolders.
    earlier_marker = %DatabaseProducer.CacheEntryMarker{
      id: marker1.id,
      timestamp: DateTime.add(marker1.timestamp, -1, :microsecond)
    }

    IndexingPipeline.write_processor_marker(%{
      type: Figgy.HydrationProducerSource.processor_marker_key(),
      cache_version: cache_version,
      cache_location: earlier_marker.timestamp,
      cache_record_id: earlier_marker.id
    })
  end

  def start_producer(cache_version \\ 0) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:database_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, hydrator} =
      Figgy.HydrationConsumer.start_link(
        cache_version: cache_version,
        producer_module: MockFiggyHydrationProducer,
        producer_options: {self(), cache_version},
        batch_size: 1
      )

    hydrator
  end

  test "hydration cache entry creation" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.markers()
    jump_processor_to_ephemera_folder()
    hydrator = start_producer()

    MockFiggyHydrationProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "internal_resource" => "EphemeraFolder"
           } = cache_entry.data

    hydrator |> Broadway.stop(:normal)
  end

  test "hydration cache entry creation with cache_version > 0" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.markers()
    jump_processor_to_ephemera_folder(1)
    hydrator = start_producer(1)

    MockFiggyHydrationProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 1
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "internal_resource" => "EphemeraFolder"
           } = cache_entry.data

    processor_marker = IndexingPipeline.get_processor_marker!("figgy_hydrator", 1)
    assert processor_marker.cache_version == 1

    hydrator |> Broadway.stop(:normal)
  end

  test "doesn't override newer hydration cache entries" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.markers()
    # Create a hydration cache entry for a record that has a source_cache_order
    # in the future.
    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: ~U[2200-03-09 20:19:33.414040Z],
      data: %{}
    })

    # Process that past record.
    jump_processor_to_ephemera_folder()
    hydrator = start_producer()
    MockFiggyHydrationProducer.process(1)
    assert_receive {:ack_done}
    hydrator |> Broadway.stop(:normal)
    # Ensure there's only one hydration cache entry.
    entries = IndexingPipeline.list_hydration_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == ~U[2200-03-09 20:19:33.414040Z]
  end

  test "updates existing hydration cache entries" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.markers()
    # Create a hydration cache entry for a record that has a source_cache_order
    # in the future.
    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: ~U[1900-03-09 20:19:33.414040Z],
      data: %{}
    })

    # Process that past record.
    jump_processor_to_ephemera_folder()
    hydrator = start_producer()
    MockFiggyHydrationProducer.process(1)
    assert_receive {:ack_done}
    hydrator |> Broadway.stop(:normal)
    # Ensure there's only one hydration cache entry.
    entries = IndexingPipeline.list_hydration_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == marker1.timestamp
  end

  test "loads a marker from the database on startup" do
    {marker1, marker2, _marker3} = FiggyTestFixtures.markers()
    # Create a marker
    IndexingPipeline.write_processor_marker(%{
      type: "figgy_hydrator",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    # Start the producer
    hydrator = start_producer()
    # Make sure the first record that comes back is what we expect
    MockFiggyHydrationProducer.process(1)
    assert_receive {:ack_done}
    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == marker2.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker2.timestamp
    hydrator |> Broadway.stop(:normal)
  end
end
