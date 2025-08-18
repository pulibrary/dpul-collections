defmodule MockFiggyHydrationProducer do
  @moduledoc """
  A producer used for tests that allows you to control how many Figgy records
  are provided to the Figgy.HydrationConsumer via .process/1.

  Figgy.HydrationConsumer demands from MockFiggyHydrationProducer, which never returns records 
  until asked by .process/1. When .process/1 is called, MockConsumer requests <demand>
  records from Figgy.HydrationProducer, and when it gets them it sends a message to
  MockFiggyHydrationProducer, which then sends those records to Figgy.HydrationConsumer.
  """
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  use GenStage

  @impl GenStage
  @type state :: %{consumer_pid: pid(), test_runner_pid: pid(), figgy_producer_pid: pid()}
  @spec init({pid(), Integer}) :: {:producer, state()}
  def init({test_runner_pid, cache_version}) do
    {:ok, figgy_producer_pid} =
      DatabaseProducer.start_link({Figgy.HydrationProducerSource, cache_version})

    {:ok, consumer_pid} = MockConsumer.start_link(figgy_producer_pid)

    {:producer,
     %{
       consumer_pid: consumer_pid,
       test_runner_pid: test_runner_pid,
       figgy_producer_pid: figgy_producer_pid
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
  MockConsumer sends this message - when received, tell the test runner and return the messages to the Figgy.HydrationConsumer.
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
  Request Figgy.HydrationConsumer to process <demand> records.
  """
  @spec process(Integer) :: :ok
  def process(demand, cache_version \\ 0) do
    # Get the PID for TestFiggyProducer GenServer,
    # then cast fulfill message to itself

    Broadway.producer_names(
      String.to_existing_atom("#{Figgy.HydrationConsumer}_#{cache_version}")
    )
    |> hd
    |> GenServer.cast({:fulfill_messages, demand})
  end
end
