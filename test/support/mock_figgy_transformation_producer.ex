defmodule MockFiggyTransformationProducer do
  @moduledoc """
  A producer used for tests that allows you to control how many Hydration cache
  entries are provided to the Figgy.TransformationConsumer via .process/1.

  Figgy.TransformationConsumer demands from MockFiggyTransformationProducer, which never returns
  records until asked by .process/1. When .process/1 is called, MockConsumer
  requests <demand> records from Figgy.TransformationProducerSource, and when it gets them it
  sends a message to MockFiggyTransformationProducer, which then sends those records
  to Figgy.TransformationConsumer.
  """
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  use GenStage

  @impl GenStage
  @type state :: %{
          consumer_pid: pid(),
          test_runner_pid: pid(),
          transformation_producer_pid: pid()
        }
  @spec init({pid(), Integer}) :: {:producer, state()}

  def init({test_runner_pid, cache_version}), do: init({test_runner_pid, cache_version, nil})

  def init({test_runner_pid, cache_version, ecto_pid}) do
    {:ok, transformation_producer_pid} =
      DatabaseProducer.start_link({Figgy.TransformationProducerSource, cache_version, ecto_pid})

    {:ok, consumer_pid} = MockConsumer.start_link(transformation_producer_pid)

    {:producer,
     %{
       consumer_pid: consumer_pid,
       test_runner_pid: test_runner_pid,
       transformation_producer_pid: transformation_producer_pid,
       ecto_pid: ecto_pid
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
  MockConsumer sends this message - when received, tell the test runner and return the messages to the Hydrator.
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
  Request Figgy.TransformationConsumer to process <demand> records.
  """
  @spec process(Integer) :: :ok
  def process(demand, cache_version \\ 0) do
    # Get the PID for TestFiggyProducer GenServer,
    # then cast fulfill message to itself
    Broadway.producer_names(
      String.to_existing_atom("#{Figgy.TransformationConsumer}_#{cache_version}")
    )
    |> hd
    |> GenServer.cast({:fulfill_messages, demand})
  end
end
