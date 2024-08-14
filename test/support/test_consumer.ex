defmodule TestConsumer do
  def start_link(producer) do
    GenStage.start_link(__MODULE__, {producer, self()})
  end

  def init({producer_pid, receive_target_pid}) do
    {:consumer, %{receive_target_pid: receive_target_pid, subscription: nil}, subscribe_to: [producer_pid]}
  end

  def handle_subscribe(:producer, _options, from, state) do
    new_state = %{state | subscription: from}
    {:manual, new_state}
  end

  def handle_events(events, _from, state) do
    send(state.receive_target_pid, {:received, events})
    {:noreply, [], state}
  end

  def handle_cast({:request, demand}, state) do
    GenStage.ask(state.subscription, demand)
    {:noreply, [], state}
  end

  def request(consumer_pid, demand) do
    GenServer.cast(consumer_pid, {:request, demand})
  end
end
