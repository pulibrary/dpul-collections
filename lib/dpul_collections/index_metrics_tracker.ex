defmodule DpulCollections.IndexMetricsTracker do
  use GenServer
  alias DpulCollections.IndexingPipeline.Metrics
  alias DpulCollections.IndexingPipeline.DatabaseProducer

  @type processor_state :: %{
          start_time: integer(),
          end_time: integer(),
          polling_started: boolean(),
          acked_count: integer()
        }
  @type state :: %{(processor_key :: String.t()) => processor_state()}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ok =
      :telemetry.attach(
        "metrics-ack-tracker",
        [:database_producer, :ack, :done],
        &handle_ack_received/4,
        nil
      )

    {:ok, %{}}
  end

  @spec register_fresh_index(source :: module()) :: term()
  def register_fresh_index(source) do
    GenServer.call(__MODULE__, {:fresh_index, source})
  end

  @spec register_polling_started(source :: module()) :: term()
  def register_polling_started(source) do
    GenServer.call(__MODULE__, {:poll_started, source})
  end

  @spec processor_durations(source :: module()) :: term()
  def processor_durations(source) do
    Metrics.index_metrics(source.processor_marker_key(), "full_index")
  end

  def reset() do
    GenServer.call(__MODULE__, {:reset})
  end

  @impl true
  @spec handle_call(term(), term(), state()) :: term()
  def handle_call({:reset}, _, _state) do
    {:reply, nil, %{}}
  end

  @impl true
  @spec handle_call(term(), term(), state()) :: term()
  def handle_call({:fresh_index, source}, _, state) do
    new_state =
      put_in(state, [source.processor_marker_key()], %{
        start_time: :erlang.monotonic_time(),
        acked_count: 0
      })

    {:reply, nil, new_state}
  end

  @spec handle_call(term(), term(), state()) :: term()
  def handle_call({:poll_started, source}, _, state) do
    # Record that polling has started if we've recorded a start time but not an
    # end time for a source. Then the next time the source finishes acknowledgements
    # we'll record an end time.
    if get_in(state, [source.processor_marker_key(), :start_time]) != nil &&
         get_in(state, [source.processor_marker_key(), :end_time]) == nil do
      state = put_in(state, [source.processor_marker_key(), :polling_started], true)

      {:reply, nil, state}
    else
      {:reply, nil, state}
    end
  end

  @spec handle_call(term(), term(), state()) :: term()
  def handle_call(
        {:ack_received, metadata = %{processor_marker_key: processor_marker_key}},
        _,
        state
      ) do
    state =
      state
      |> put_in(
        [processor_marker_key],
        handle_ack_received(metadata, Map.get(state, processor_marker_key))
      )

    {:reply, nil, state}
  end

  # If there's no stored info yet, do nothing.
  @spec handle_ack_received(DatabaseProducer.ack_event_metadata(), processor_state()) ::
          processor_state()
  defp handle_ack_received(_event, nil), do: nil
  # If there's a start and end time, do nothing
  defp handle_ack_received(
         _event,
         processor_state = %{start_time: _start_time, end_time: _end_time}
       ),
       do: processor_state

  # If there's a start, trigger for end time, and the unacked_count is 0, create the IndexMetric.
  defp handle_ack_received(
         %{
           processor_marker_key: processor_marker_key,
           acked_count: new_acked_count,
           unacked_count: 0
         },
         processor_state = %{
           start_time: _start_time,
           polling_started: true,
           acked_count: old_acked_count
         }
       ) do
    processor_state =
      processor_state
      |> put_in([:end_time], :erlang.monotonic_time())
      |> Map.delete(:polling_started)
      |> put_in([:acked_count], old_acked_count + new_acked_count)

    duration = processor_state[:end_time] - processor_state[:start_time]

    :telemetry.execute(
      [:dpulc, :indexing_pipeline, event(processor_marker_key), :time_to_poll],
      %{duration: duration},
      %{source: processor_marker_key}
    )

    Metrics.create_index_metric(%{
      type: processor_marker_key,
      measurement_type: "full_index",
      duration: System.convert_time_unit(duration, :native, :second),
      records_acked: processor_state[:acked_count]
    })

    processor_state
  end

  # If there's a start time, record the acked_count
  defp handle_ack_received(
         %{acked_count: new_acked_count},
         processor_state = %{start_time: _start_time, acked_count: old_acked_count}
       ) do
    processor_state
    |> put_in([:acked_count], old_acked_count + new_acked_count)
  end

  defp handle_ack_received([:database_producer, :ack, :done], _measurements, metadata, _config) do
    GenServer.call(__MODULE__, {:ack_received, metadata})
  end

  def event("figgy_hydrator") do
    :hydrator
  end

  def event("figgy_transformer") do
    :transformer
  end

  def event("figgy_indexer") do
    :indexer
  end
end
