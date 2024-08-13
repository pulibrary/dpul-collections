defmodule TestConsumer do
  def start_link(producer) do
    GenStage.start_link(__MODULE__, {producer, self()})
  end

  def init({producer, owner}) do
    {:consumer, %{owner: owner, subscription: nil}, subscribe_to: [producer]}
  end

  def handle_subscribe(:producer, _options, from, state) do
    new_state = %{state | subscription: from}
    {:manual, new_state}
  end

  def handle_events(events, _from, state) do
    send(state.owner, {:received, events})
    {:noreply, [], state.owner}
  end

  def handle_cast({:request, demand}, state) do
    GenStage.ask(state.subscription, demand)
    {:noreply, [], state}
  end

  def request(pid, demand) do
    GenServer.cast(pid, { :request, demand })
  end
end
