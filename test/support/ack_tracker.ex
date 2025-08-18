defmodule AckTracker do
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  use GenServer
  import ExUnit.Assertions
  @impl true
  def init(pid) do
    ack_handler_id = "ack-waiter-#{pid |> :erlang.pid_to_list()}"
    message_handler_id = "message-waiter-#{pid |> :erlang.pid_to_list()}"
    processor_handler_id = "processor-waiter-#{pid |> :erlang.pid_to_list()}"
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
      message_handler_id,
      [:broadway, :batch_processor, :stop],
      fn _, _measurements, metadata, _ ->
        GenServer.cast(tracker_pid, {:processed, metadata})
      end,
      nil
    )

    :telemetry.attach(
      processor_handler_id,
      [:broadway, :processor, :start],
      fn _, _measurements, metadata, _ ->
        GenServer.cast(tracker_pid, {:processor, metadata})
      end,
      nil
    )

    {:ok, %{pid: pid}}
  end

  def wait_for_indexed_count(count) do
    assert_receive({:ack_status, %{"figgy_indexer" => %{1 => %{acked_count: ^count}}}}, 30_000)
    Solr.soft_commit()
  end

  def reset_count!(pid) do
    GenServer.call(pid, {:reset_count})
  end

  @impl true
  def handle_call({:reset_count}, _from, %{pid: pid}) do
    {:reply, :ok, %{pid: pid}}
  end

  @impl true
  def handle_cast({:processed, %{producer: producer, successful_messages: success}}, state) do
    {_producer_module, {_source, cache_version, %{type: type}}} = producer

    {_, state} =
      get_and_update_in(
        state,
        [Access.key(type, %{}), Access.key(cache_version, %{}), Access.key(:batched_count, 0)],
        &{&1, &1 + length(success)}
      )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:processor, metadata = %{producer: producer, messages: messages}}, state) do
    {_producer_module, {_source, cache_version, %{type: type}}} = producer

    {_, state} =
      get_and_update_in(
        state,
        [
          Access.key(type, %{}),
          Access.key(cache_version, %{}),
          Access.key(:requested_for_processing_count, 0)
        ],
        &{&1, &1 + length(messages)}
      )

    {:noreply, state}
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
