defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.{FiggyRepo, Repo}
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    :ok
  end

  def start_figgy_producer(batch_size \\ 1) do
    {:ok, hydrator} =
      Figgy.HydrationConsumer.start_link(
        cache_version: 0,
        producer_module: MockFiggyHydrationProducer,
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
      Figgy.TransformationConsumer.start_link(
        cache_version: 0,
        batch_size: batch_size
      )

    transformer
  end

  def start_indexing_producer(batch_size \\ 1) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:indexing_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, indexer} =
      Figgy.IndexingConsumer.start_link(
        cache_version: 0,
        batch_size: batch_size
      )

    indexer
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
    case IndexingPipeline.get_processor_marker!("figgy_transformer", 0) do
      %{cache_record_id: ^id} ->
        true

      _ ->
        :timer.sleep(50)
        wait_for_transformed_id(id, cache_version)
    end
  end

  def wait_for_indexed_id(id, cache_version \\ 0) do
    case IndexingPipeline.get_processor_marker!("figgy_indexer", 0) do
      %{cache_record_id: ^id} ->
        true

      _ ->
        :timer.sleep(50)
        wait_for_indexed_id(id, cache_version)
    end
  end

  test "a full hydrator and transformer run" do
    # Start the figgy producer
    hydrator = start_figgy_producer(50)
    transformer = start_transformer_producer(50)
    indexer = start_indexing_producer(50)
    # Demand all of them.
    count = FiggyRepo.aggregate(Figgy.Resource, :count)
    MockFiggyHydrationProducer.process(count)
    # Wait for the last ID to show up.
    task =
      Task.async(fn -> wait_for_hydrated_id(FiggyTestSupport.last_figgy_resource_marker().id) end)

    Task.await(task, 15000)

    task =
      Task.async(fn -> wait_for_transformed_id(FiggyTestSupport.last_ephemera_folder_id()) end)

    Task.await(task, 15000)
    Solr.commit()

    # the hydrator pulled all ephemera folders and terms
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count

    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)

    # the transformer only processes ephemera folders
    assert FiggyTestSupport.ephemera_folder_count() == transformation_cache_entry_count

    # Start the indexing producer
    assert Solr.document_count() == transformation_cache_entry_count

    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)
  end
end
