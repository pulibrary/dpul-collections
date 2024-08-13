defmodule FiggyTestProducer do
  alias DpulCollections.IndexingPipeline.FiggyHydrator
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenStage
  def init({producer_stage, owner}) do
    {:ok, cons} = TestConsumer.start_link(producer_stage)
    {:producer, %{consumer: cons, owner: owner}}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({:received, messages}, state) do
    send(state.owner, {:received, messages})
    {:noreply, messages, state}
  end

  @impl GenStage
  def handle_cast({:fulfill_messages, demand}, state) do
    TestConsumer.request(state.consumer, demand)
    {:noreply, [], state}
  end

  def process(demand) do
    Broadway.producer_names(FiggyHydrator)
    |> hd
    |> GenServer.cast({ :fulfill_messages, demand })
  end
end

