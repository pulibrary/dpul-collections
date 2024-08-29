defmodule DpulCollections.IndexingPipeline.FiggyHydratorIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.{FiggyRepo, Repo}
  alias DpulCollections.IndexingPipeline.{FiggyHydrator, FiggyResource, HydrationCacheEntry}
  alias DpulCollections.IndexingPipeline

  def start_producer(batch_size \\ 1) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:figgy_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, hydrator} =
      FiggyHydrator.start_link(
        cache_version: 0,
        producer_module: FiggyTestProducer,
        producer_options: {self()},
        batch_size: batch_size
      )

    hydrator
  end

  test "hydration cache entry creation" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.markers()
    hydrator = start_producer()

    FiggyTestProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == marker1.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker1.timestamp
    marker_1_id = marker1.id

    assert %{
             "id" => ^marker_1_id,
             "internal_resource" => "EphemeraTerm"
           } = cache_entry.data

    hydrator |> Broadway.stop(:normal)
  end

  test "doesn't override newer hydration cache entries" do
    # Create a hydration cache entry for a record that has a source_cache_order
    # in the future.
    IndexingPipeline.write_hydration_cache_entry(%{
      cache_version: 0,
      record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
      source_cache_order: ~U[2200-03-09 20:19:33.414040Z],
      data: %{}
    })

    # Process that past record.
    hydrator = start_producer()
    FiggyTestProducer.process(1)
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
      record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
      source_cache_order: ~U[1900-03-09 20:19:33.414040Z],
      data: %{}
    })

    # Process that past record.
    hydrator = start_producer()
    FiggyTestProducer.process(1)
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
      type: "hydrator",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    # Start the producer
    hydrator = start_producer()
    # Make sure the first record that comes back is what we expect
    FiggyTestProducer.process(1)
    assert_receive {:ack_done}
    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == marker2.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker2.timestamp
    hydrator |> Broadway.stop(:normal)
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

  test "a full hydration run" do
    # Start the producer
    hydrator = start_producer(50)
    # Demand all of them.
    count = FiggyRepo.aggregate(FiggyResource, :count)
    FiggyTestProducer.process(count)
    # Wait for the last ID to show up.
    task = Task.async(fn -> wait_for_hydrated_id(FiggyTestSupport.last_marker().id) end)
    Task.await(task, 15000)
    entry_count = Repo.aggregate(HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count
    :timer.sleep(2000)
    hydrator |> Broadway.stop(:normal)
  end
end
