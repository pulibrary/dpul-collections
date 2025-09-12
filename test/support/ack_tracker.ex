defmodule AckTracker do
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

  def reset_count!(pid) do
    FiggyTestSupport.flush_messages()
    GenServer.call(pid, {:reset_count})
  end

  @impl true
  def handle_call({:reset_count}, _from, %{pid: pid}) do
    {:reply, :ok, %{pid: pid}}
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
