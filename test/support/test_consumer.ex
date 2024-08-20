defmodule TestConsumer do
  @moduledoc """
  TestConsumer allows for manual consumption of messages from a Producer and
  then notifies a receive_target of any messages it gets. We largely use this
  for integration tests.
  """
  use GenStage

  def start_link(producer) do
    GenStage.start_link(__MODULE__, {producer, self()})
  end

  @impl GenStage
  def init({producer_pid, receive_target_pid}) do
    {:consumer, %{receive_target_pid: receive_target_pid, subscription: nil},
     subscribe_to: [producer_pid]}
  end

  @impl GenStage
  def handle_subscribe(:producer, _options, from, state) do
    new_state = %{state | subscription: from}
    {:manual, new_state}
  end

  @type test_consumer_message :: {:received, [%Broadway.Message{}]}
  @impl GenStage
  def handle_events(events, _from, state) do
    send(state.receive_target_pid, {:received, events})
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_cast({:request, demand}, state) do
    GenStage.ask(state.subscription, demand)
    {:noreply, [], state}
  end

  def request(consumer_pid, demand) do
    GenServer.cast(consumer_pid, {:request, demand})
  end
end
