defmodule MockFiggyIndexingProducer do
  @moduledoc """
  A producer used for tests that allows you to control how many Transformation cache
  entries are provided to the Figgy.IndexingConsumer via .process/1.

  Figgy.IndexingConsumer demands from MockFiggyIndexingProducer, which never returns
  records until asked by .process/1. When .process/1 is called, MockConsumer
  requests <demand> records from Figgy.IndexingProducer, and when it gets them it
  sends a message to MockFiggyIndexingProducer, which then sends those records
  to Figgy.IndexingConsumer.
  """
  alias DpulCollections.IndexingPipeline.Figgy
  use GenStage

  @impl GenStage
  @type state :: %{consumer_pid: pid(), test_runner_pid: pid(), indexing_producer_pid: pid()}
  @spec init({pid(), Integer}) :: {:producer, state()}
  def init({test_runner_pid, cache_version}) do
    {:ok, indexing_producer_pid} =
      Figgy.DatabaseProducer.start_link({Figgy.IndexingProducer, cache_version})

    {:ok, consumer_pid} = MockConsumer.start_link(indexing_producer_pid)

    {:producer,
     %{
       consumer_pid: consumer_pid,
       test_runner_pid: test_runner_pid,
       indexing_producer_pid: indexing_producer_pid
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
  MockConsumer sends this message - when received, tell the test runner and return the messages.
  """
  @spec handle_info(MockConsumer.test_consumer_message(), state()) ::
          {:noreply, [%Broadway.Message{}], state()}
  def handle_info({:received, messages}, state) do
    send(state.test_runner_pid, {:received, messages})
    {:noreply, messages, state}
  end

  @impl GenStage
  @doc """
  The TestProducer process receives this message from process/1 so that we can
  pass the pid to MockConsumer.
  """
  def handle_cast({:fulfill_messages, demand}, state) do
    MockConsumer.request(state.consumer_pid, demand)
    {:noreply, [], state}
  end

  @doc """
  Request Figgy.IndexingConsumer to process <demand> records.
  """
  @spec process(Integer) :: :ok
  def process(demand) do
    # Get the PID for TestFiggyProducer GenServer,
    # then cast fulfill message to itself
    Broadway.producer_names(Figgy.IndexingConsumer)
    |> hd
    |> GenServer.cast({:fulfill_messages, demand})
  end
end
