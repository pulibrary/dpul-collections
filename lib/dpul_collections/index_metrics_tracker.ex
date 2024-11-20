defmodule DpulCollections.IndexMetricsTracker do
  use GenServer
  alias DpulCollections.IndexingPipeline.Metrics
  alias DpulCollections.IndexingPipeline.Figgy

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_fresh_index(source) do
    GenServer.call(__MODULE__, {:fresh_index, source})
  end

  def register_polling_started(source) do
    GenServer.call(__MODULE__, {:poll_started, source})
  end

  def index_times(source) do
    Metrics.index_metrics(source.processor_marker_key(), "full_index")
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:fresh_index, source}, _, state) do
    new_state = put_in(state, [source], %{start_time: :erlang.monotonic_time()})
    {:reply, nil, new_state}
  end

  def handle_call({:poll_started, source}, _, state) do
    if get_in(state, [source, :start_time]) != nil && get_in(state, [source, :end_time]) == nil do
      state = put_in(state, [source, :end_time], :erlang.monotonic_time())
      duration = state[source][:end_time] - state[source][:start_time]

      :telemetry.execute(
        [:dpulc, :indexing_pipeline, event(source), :time_to_poll],
        %{duration: duration},
        %{source: source}
      )

      Metrics.create_index_metric(%{
        type: source.processor_marker_key(),
        measurement_type: "full_index",
        duration: System.convert_time_unit(duration, :native, :millisecond)
      })

      {:reply, nil, state}
    else
      {:reply, nil, state}
    end
  end

  def event(Figgy.HydrationProducerSource) do
    :hydrator
  end

  def event(Figgy.TransformationProducerSource) do
    :transformer
  end

  def event(Figgy.IndexingProducerSource) do
    :indexer
  end
end
