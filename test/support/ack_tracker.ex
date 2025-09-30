defmodule AckTracker do
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
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

    :telemetry.attach(
      "persisted_marker-#{tracker_pid |> :erlang.pid_to_list()}",
      [:database_producer, :persisted_marker],
      fn _, _, metadata, _ ->
        GenServer.cast(tracker_pid, {:marker_persisted, metadata})
      end,
      nil
    )

    {:ok, %{pid: pid}}
  end

  def wait_for_indexed_count(count) do
    assert_receive({:ack_status, %{"figgy_indexer" => %{1 => %{acked_count: ^count}}}}, 30_000)
    Solr.soft_commit()
  end

  def wait_for_pipeline_finished(tracker_pid, cache_version \\ 1) do
    tracker_pid
    |> wait_for_hydrator(cache_version)
    |> wait_for_transformer(cache_version)
    |> wait_for_indexer(cache_version)
  end

  def wait_for_transformer(tracker_pid, cache_version) do
    # Get the last hydration cache entry
    hydration_marker =
      IndexingPipeline.get_hydration_cache_entries_since!(nil, 10_000, 1)
      |> Enum.at(-1)
      |> CacheEntryMarker.from()

    # Wait until that cache entry is persisted - then transformation is done.
    wait_for_persisted_marker(tracker_pid, hydration_marker, "figgy_transformer", cache_version)
    tracker_pid
  end

  def wait_for_indexer(tracker_pid, cache_version) do
    # Get the last transformation cache entry
    transformation_marker =
      IndexingPipeline.get_transformation_cache_entries_since!(nil, 10_000, 1)
      |> Enum.at(-1)
      |> CacheEntryMarker.from()

    # Wait until that cache entry is persisted - then indexing is done.
    wait_for_persisted_marker(tracker_pid, transformation_marker, "figgy_indexer", cache_version)
    Solr.soft_commit()
  end

  def wait_for_hydrator(tracker_pid, cache_version) do
    # Get the last Figgy entry
    figgy_marker =
      IndexingPipeline.get_figgy_resources_since!(nil, 10_000)
      |> Enum.at(-1)
      |> CacheEntryMarker.from()

    # Wait until that cache entry is persisted - then indexing is done.
    wait_for_persisted_marker(tracker_pid, figgy_marker, "figgy_hydrator", cache_version)
    tracker_pid
  end

  def wait_for_persisted_marker(pid, target_marker, type, cache_version) do
    current_marker = GenServer.call(pid, {:get_last_persisted_marker, type, cache_version})

    cond do
      current_marker == target_marker ->
        true

      true ->
        :timer.sleep(100)
        wait_for_persisted_marker(pid, target_marker, type, cache_version)
    end
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

  def handle_call({:get_last_persisted_marker, processor_marker_key, cache_version}, _from, state) do
    last_marker =
      get_in(state, [
        Access.key(processor_marker_key, %{}),
        Access.key(cache_version),
        Access.key(:last_persisted_marker, nil)
      ])

    {:reply, last_marker, state}
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

  def handle_cast(
        {:marker_persisted,
         %{
           marker: marker,
           processor_marker_key: processor_marker_key,
           cache_version: cache_version
         }},
        state
      ) do
    state =
      state
      |> put_in(
        [
          Access.key(processor_marker_key, %{}),
          Access.key(cache_version, %{}),
          Access.key(:last_persisted_marker, marker)
        ],
        marker
      )

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
