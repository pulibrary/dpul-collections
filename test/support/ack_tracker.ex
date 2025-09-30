defmodule AckTracker do
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.Repo
  alias DpulCollections.Solr
  use GenServer
  import ExUnit.Assertions
  @impl true
  def init(pid) do
    ack_handler_id = "ack-waiter-#{pid |> :erlang.pid_to_list()}"
    tracker_pid = self()

    :telemetry.attach(
      ack_handler_id,
      [:database_producer, :ack, :done],
      fn _, _measurements, metadata, _ ->
        GenServer.cast(tracker_pid, {:ack, metadata})
      end,
      nil
    )

    {:ok, %{pid: pid}}
  end

  def wait_for_indexed_count(count) do
    assert_receive({:ack_status, %{"figgy_indexer" => %{1 => %{acked_count: ^count}}}}, 30_000)
    Solr.soft_commit()
  end

  def wait_for_pipeline_finished(tracker_pid) do
    test_pid = self()

    :telemetry.attach(
      "hydration-full-run-#{tracker_pid |> :erlang.pid_to_list()}",
      [:dpulc, :indexing_pipeline, :hydrator, :time_to_poll],
      fn _, measurements, _, _ ->
        send(test_pid, {:hydrator_finished, measurements})
        :ok
      end,
      nil
    )

    :telemetry.attach(
      "persisted_marker-#{tracker_pid |> :erlang.pid_to_list()}",
      [:database_producer, :persisted_marker],
      fn _, _, metadata, _ ->
        send(test_pid, {:marker_persisted, metadata})
        :ok
      end,
      nil
    )

    # First the hydrator finishes.
    assert_receive({:hydrator_finished, _}, 30_000)
    :telemetry.detach("hydration-full-run-#{tracker_pid |> :erlang.pid_to_list()}")
    # Get the last hydration cache entry
    hydration_marker =
      IndexingPipeline.get_hydration_cache_entries_since!(nil, 10_000, 1)
      |> Enum.at(-1)
      |> CacheEntryMarker.from()

    # Wait until that cache entry is persisted - then transformation is done.
    assert_receive(
      {:marker_persisted,
       %{marker: ^hydration_marker, processor_marker_key: "figgy_transformer"}},
      10_000
    )

    # Get the last transformation cache entry
    transformation_marker =
      IndexingPipeline.get_transformation_cache_entries_since!(nil, 10_000, 1)
      |> Enum.at(-1)
      |> CacheEntryMarker.from()

    # Wait until that cache entry is persisted - then indexing is done.
    assert_receive(
      {:marker_persisted,
       %{marker: ^transformation_marker, processor_marker_key: "figgy_indexer"}},
      30_000
    )

    :telemetry.detach("persisted_marker-#{tracker_pid |> :erlang.pid_to_list()}")
    Solr.soft_commit()
  end

  def wait_for_ack_count(pid, type, target_count) do
    current_count = GenServer.call(pid, {:get_count, type})

    cond do
      current_count < target_count ->
        :timer.sleep(100)
        wait_for_ack_count(pid, type, target_count)

      true ->
        true
    end
  end

  def wait_for_transformed_count(count) do
    assert_receive(
      {:ack_status, %{"figgy_transformer" => %{1 => %{acked_count: ^count}}}},
      30_000
    )
  end

  def reset_count!(pid) do
    FiggyTestSupport.flush_messages()
    GenServer.call(pid, {:reset_count})
  end

  @impl true
  def handle_call({:reset_count}, _from, %{pid: pid}) do
    {:reply, :ok, %{pid: pid}}
  end

  def handle_call({:get_count, processor_marker_key}, _from, state) do
    count =
      get_in(state, [
        Access.key(processor_marker_key, %{}),
        Access.key(1),
        Access.key(:acked_count, 0)
      ])

    {:reply, count, state}
  end

  @impl true
  def handle_cast(
        {:ack,
         metadata = %{
           cache_version: _cache_version,
           processor_marker_key: _processor_marker_key,
           acked_count: _acked_count
         }},
        state = %{pid: pid}
      ) do
    state = state |> append_ack(metadata)
    send(pid, {:ack_status, state |> Map.delete(:pid)})

    {:noreply, state}
  end

  def append_ack(state, %{
        cache_version: cache_version,
        processor_marker_key: processor_marker_key,
        acked_count: acked_count
      }) do
    {_, state} =
      get_and_update_in(
        state,
        [
          Access.key(processor_marker_key, %{}),
          Access.key(cache_version, %{}),
          Access.key(:acked_count, 0)
        ],
        &{&1, &1 + acked_count}
      )

    state
  end
end
