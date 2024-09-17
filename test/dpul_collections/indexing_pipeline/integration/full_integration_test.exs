defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.{FiggyRepo, Repo}
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline

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
        producer_module: MockFiggyTransformationProducer,
        producer_options: {self()},
        batch_size: batch_size
      )

    transformer
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

  test "a full hydrator and transformer run" do
    # Start the figgy producer
    hydrator = start_figgy_producer(50)
    # Demand all of them.
    count = FiggyRepo.aggregate(Figgy.Resource, :count)
    MockFiggyHydrationProducer.process(count)
    # Wait for the last ID to show up.
    task =
      Task.async(fn -> wait_for_hydrated_id(FiggyTestSupport.last_figgy_resource_marker().id) end)

    Task.await(task, 15000)
    :timer.sleep(2000)
    hydrator |> Broadway.stop(:normal)

    # the hydrator pulled all ephemera folders and terms
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count

    # Start the transformer producer
    transformer = start_transformer_producer(50)
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    MockFiggyTransformationProducer.process(entry_count)
    # Wait for the last ID to show up.
    task =
      Task.async(fn ->
        wait_for_transformed_id(FiggyTestSupport.last_hydration_cache_entry_marker().id)
      end)

    Task.await(task, 15000)
    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)

    # the transformer only processes ephemera folders
    assert FiggyTestSupport.ephemera_folder_count() == transformation_cache_entry_count
    :timer.sleep(2000)
    transformer |> Broadway.stop(:normal)

    # query everything and return the count
    response = Req.get(
      Application.fetch_env!(:hui, :default)[:url],
      json: %{q: "*:*"}
    )
    |> IO.inspect
    # {:ok, response} = Hui.search(:default, [q: "*:*"], Hui.Http.Client.impl())
    # {:ok, body} = Jason.decode(response.body)
    # total_hits = body["response"]["numFound"]
    # assert total_hits == 0
  end
end
