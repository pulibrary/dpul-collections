defmodule TestFiggyTransformerProducer do
  @moduledoc """
  A producer used for tests that allows you to control how many Hydration cache
  entries are provided to the FiggyTransformer via .process/1.

  FiggyTransformer demands from TestFiggyTransformerProducer, which never returns
  records until asked by .process/1. When .process/1 is called, TestConsumer
  requests <demand> records from FiggyTransformerProducer, and when it gets them it
  sends a message to TestFiggyTransformerProducer, which then sends those records
  to FiggyTransformer.
  """
  alias DpulCollections.IndexingPipeline.{FiggyTransformer, FiggyTransformerProducer}
  use GenStage

  @impl GenStage
  @type state :: %{consumer_pid: pid(), test_runner_pid: pid(), transformer_producer_pid: pid()}
  @spec init({pid()}) :: {:producer, state()}
  def init({test_runner_pid}) do
    {:ok, transformer_producer_pid} = FiggyTransformerProducer.start_link()
    {:ok, consumer_pid} = TestConsumer.start_link(transformer_producer_pid)

    {:producer,
     %{
       consumer_pid: consumer_pid,
       test_runner_pid: test_runner_pid,
       transformer_producer_pid: transformer_producer_pid
     }}
  end

  @impl GenStage
  @doc """
  Never return demand when requested - only when process/1 is run.
  """
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  @doc """
  TestConsumer sends this message - when received, tell the test runner and return the messages to the Hydrator.
  """
  @spec handle_info(TestConsumer.test_consumer_message(), state()) ::
          {:noreply, [%Broadway.Message{}], state()}
  def handle_info({:received, messages}, state) do
    send(state.test_runner_pid, {:received, messages})
    {:noreply, messages, state}
  end

  @impl GenStage
  @doc """
  The TestProducer process receives this message from process/1 so that we can
  pass the pid to TestConsumer.
  """
  def handle_cast({:fulfill_messages, demand}, state) do
    TestConsumer.request(state.consumer_pid, demand)
    {:noreply, [], state}
  end

  @doc """
  Request FiggyTransformer to process <demand> records.
  """
  @spec process(Integer) :: :ok
  def process(demand) do
    # Get the PID for TestFiggyProducer GenServer,
    # then cast fulfill message to itself
    Broadway.producer_names(FiggyTransformer)
    |> hd
    |> GenServer.cast({:fulfill_messages, demand})
  end
end