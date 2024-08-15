defmodule FiggyTestProducer do
  alias DpulCollections.IndexingPipeline.{ FiggyHydrator, FiggyProducer }
  use GenStage

  @impl GenStage
  def init({test_runner_pid}) do
    {:ok, figgy_producer_pid} = FiggyProducer.start_link()
    {:ok, consumer_pid} = TestConsumer.start_link(figgy_producer_pid)
    {:producer, %{consumer_pid: consumer_pid, test_runner_pid: test_runner_pid}}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  # The received message comes from TestConsumer
  def handle_info({:received, messages}, state) do
    send(state.test_runner_pid, {:received, messages})
    {:noreply, messages, state}
  end

  @impl GenStage
  def handle_cast({:fulfill_messages, demand}, state) do
    TestConsumer.request(state.consumer_pid, demand)
    {:noreply, [], state}
  end

  def process(demand) do
    # Get the PID for FiggyTestProducer GenServer,
    # then cast fulfill message to itself
    Broadway.producer_names(FiggyHydrator)
    |> hd
    |> GenServer.cast({:fulfill_messages, demand})
  end
end
