defmodule DpulCollections.IndexingPipeline.FiggyTransformerIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.{FiggyRepo, Repo}

  alias DpulCollections.IndexingPipeline.{
    FiggyHydrator,
    FiggyResource,
    FiggyTransformer,
    HydrationCacheEntry,
    TransformationCacheEntry
  }

  alias DpulCollections.IndexingPipeline

  def start_figgy_producer(batch_size \\ 1) do
    {:ok, hydrator} =
      FiggyHydrator.start_link(
        cache_version: 0,
        producer_module: FiggyTestProducer,
        producer_options: {self()},
        batch_size: batch_size
      )

    hydrator
  end

  def start_transformer_producer(batch_size \\ 1) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:transformer_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, transformer} =
      FiggyTransformer.start_link(
        cache_version: 0,
        producer_module: TestFiggyTransformerProducer,
        producer_options: {self()},
        batch_size: batch_size
      )

    transformer
  end

  test "transformation cache entry creation" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers()

    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: marker1.timestamp,
      data: %{
        "id" => marker1.id,
        "internal_resource" => "EphemeraFolder",
        "metadata" => %{"title" => ["test title"]}
      }
    })

    transformer = start_transformer_producer()

    TestFiggyTransformerProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_transformation_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "title_ssm" => ["test title"]
           } = cache_entry.data

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
    transformer = start_transformer_producer()
    TestFiggyTransformerProducer.process(1)
    assert_receive {:ack_done}
    transformer |> Broadway.stop(:normal)
    # Ensure there's only one transformation cache entry.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == ~U[2200-03-09 20:19:33.414040Z]
  end

  test "updates existing hydration cache entries" do
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
    transformer = start_transformer_producer()
    TestFiggyTransformerProducer.process(1)
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

    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: marker1.id,
      source_cache_order: marker1.timestamp,
      data: %{
        "id" => marker1.id,
        "internal_resource" => "EphemeraFolder",
        "metadata" => %{"title" => ["test title 1"]}
      }
    })

    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: marker2.id,
      source_cache_order: marker2.timestamp,
      data: %{
        "id" => marker2.id,
        "internal_resource" => "EphemeraFolder",
        "metadata" => %{"title" => ["test title 2"]}
      }
    })

    # Create a marker
    IndexingPipeline.write_processor_marker(%{
      type: "transformer",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    # Start the producer
    transformer = start_transformer_producer()
    TestFiggyTransformerProducer.process(1)
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
    transformer = start_transformer_producer()
    TestFiggyTransformerProducer.process(1)
    assert_receive {:ack_done}
    transformer |> Broadway.stop(:normal)
    # Ensure there are no transformation cache entries.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 0
  end

  def wait_for_hydrated_id(id, cache_version \\ 0) do
    case IndexingPipeline.get_processor_marker!("hydrator", 0) do
      %{cache_record_id: ^id} ->
        true

      _ ->
        :timer.sleep(50)
        wait_for_hydrated_id(id, cache_version)
    end
  end

  def wait_for_transformed_id(id, cache_version \\ 0) do
    case IndexingPipeline.get_processor_marker!("transformer", 0) do
      %{cache_record_id: ^id} ->
        true

      _ ->
        :timer.sleep(50)
        wait_for_transformed_id(id, cache_version)
    end
  end

  test "a full hydrator and transformer run" do
    # Start the figgy producer
    hydrator = start_figgy_producer(50)
    # Demand all of them.
    count = FiggyRepo.aggregate(FiggyResource, :count)
    FiggyTestProducer.process(count)
    # Wait for the last ID to show up.
    task = Task.async(fn -> wait_for_hydrated_id(FiggyTestSupport.last_marker().id) end)
    Task.await(task, 15000)
    :timer.sleep(2000)
    hydrator |> Broadway.stop(:normal)

    # Start the transformer producer
    transformer = start_transformer_producer(50)
    entry_count = Repo.aggregate(HydrationCacheEntry, :count)
    TestFiggyTransformerProducer.process(entry_count)
    # Wait for the last ID to show up.
    task =
      Task.async(fn ->
        wait_for_transformed_id(FiggyTestSupport.last_hydration_cache_entry_marker().id)
      end)

    Task.await(task, 15000)
    transformation_cache_entry_count = Repo.aggregate(TransformationCacheEntry, :count)
    assert FiggyTestSupport.ephemera_folder_count() == transformation_cache_entry_count
    :timer.sleep(2000)
    transformer |> Broadway.stop(:normal)
  end
end
