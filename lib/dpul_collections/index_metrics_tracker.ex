defmodule DpulCollections.IndexMetricsTracker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_fresh_index(source) do
    GenServer.cast(__MODULE__, { :fresh_index, source })
  end

  def register_polling_started(source) do
    GenServer.cast(__MODULE__, { :poll_started, source })
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:fresh_index, source}, state) do
    new_state = put_in(state, [source], %{start_time: :erlang.monotonic_time()})
    {:noreply, new_state}
  end

  def handle_cast({:poll_started, source}, state) do
    if get_in(state, [source, :start_time]) != nil && get_in(state, [source, :end_time]) == nil do
      state = put_in(state, [source, :end_time], :erlang.monotonic_time())
      duration = state[source][:end_time] - state[source][:start_time]
      IO.inspect("Duration (ms)(#{source}): #{System.convert_time_unit(duration, :native, :millisecond)}")
      {:noreply, state}
    else
      {:noreply, state}
    end
  end
end
