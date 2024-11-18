defmodule DpulCollections.IndexingPipeline.Figgy.TransformationIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline

  def start_transformation_producer(cache_version \\ 0) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:database_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, transformer} =
      Figgy.TransformationConsumer.start_link(
        cache_version: cache_version,
        producer_module: MockFiggyTransformationProducer,
        producer_options: {self(), cache_version},
        batch_size: 1
      )

    transformer
  end

  test "transformation cache entry creation" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

    transformer = start_transformation_producer()

    MockFiggyTransformationProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_transformation_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "title_txtm" => ["test title 1"]
           } = cache_entry.data

    transformer |> Broadway.stop(:normal)
  end

  test "transformation cache entry creation with cache version > 0" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers(1)

    cache_version = 1
    transformer = start_transformation_producer(cache_version)

    MockFiggyTransformationProducer.process(1, cache_version)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_transformation_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 1
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "title_txtm" => ["test title 1"]
           } = cache_entry.data

    processor_marker = IndexingPipeline.get_processor_marker!("figgy_transformer", 1)
    assert processor_marker.cache_version == 1

    transformer |> Broadway.stop(:normal)
  end

  test "doesn't override newer transformation cache entries" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

    # Create a tranformation cache entry for a record that has a source_cache_order
    # in the future.
    IndexingPipeline.write_transformation_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: ~U[2200-03-09 20:19:33.414040Z],
      data: %{
        "id" => marker1.id,
        "title" => ["test title"]
      }
    })

    # Process that past record.
    transformer = start_transformation_producer()
    MockFiggyTransformationProducer.process(1)
    assert_receive {:ack_done}
    transformer |> Broadway.stop(:normal)
    # Ensure there's only one transformation cache entry.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == ~U[2200-03-09 20:19:33.414040Z]
  end

  test "updates existing transformation cache entries" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

    # Create a tranformation cache entry for a record that has a source_cache_order
    # in the past.
    IndexingPipeline.write_transformation_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: ~U[1900-03-09 20:19:33.414040Z],
      data: %{
        "id" => marker1.id,
        "title" => ["test title"]
      }
    })

    # Process that past record.
    transformer = start_transformation_producer()
    MockFiggyTransformationProducer.process(1)
    assert_receive {:ack_done}
    transformer |> Broadway.stop(:normal)
    # Ensure there's only one transformation cache entry.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == marker1.timestamp
  end

  test "loads a marker from the database on startup" do
    {marker1, marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

    # Create a marker
    IndexingPipeline.write_processor_marker(%{
      type: "figgy_transformer",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    # Start the producer
    transformer = start_transformation_producer()
    MockFiggyTransformationProducer.process(1)
    assert_receive {:ack_done}
    # Make sure the first record that comes back is what we expect
    cache_entry = IndexingPipeline.list_transformation_cache_entries() |> hd
    assert cache_entry.record_id == marker2.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker2.timestamp
    transformer |> Broadway.stop(:normal)
  end

  test "doesn't process non-figgy hydration cache entries" do
    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: "some-other-id",
      source_cache_order: ~U[2100-03-09 20:19:33.414040Z],
      data: %{
        "non_figgy_property" => "stuff"
      }
    })

    # Process that past record.
    transformer = start_transformation_producer()
    MockFiggyTransformationProducer.process(1)
    assert_receive {:ack_done}
    transformer |> Broadway.stop(:normal)
    # Ensure there are no transformation cache entries.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 0
  end
end
