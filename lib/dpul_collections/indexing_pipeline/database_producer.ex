defmodule DpulCollections.IndexingPipeline.DatabaseProducer do
  @moduledoc """
  GenStage Producer that pulls records from a database.
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  use GenStage
  @behaviour Broadway.Acknowledger

  @spec start_link({source_module :: module(), cache_version :: integer()}) :: Broadway.on_start()
  def start_link({source_module, cache_version}) do
    GenStage.start_link(
      __MODULE__,
      {source_module, cache_version},
      name: String.to_atom("#{__MODULE__}_#{cache_version}")
    )
  end

  @impl GenStage
  @type state :: %{
          last_queried_marker: CacheEntryMarker.t(),
          pulled_records: [CacheEntryMarker.t()],
          acked_records: [CacheEntryMarker.t()],
          cache_version: Integer,
          stored_demand: Integer
        }
  @spec init(integer()) :: {:producer, state()}
  def init({source_module, cache_version}) do
    # trap the exit so we can stop gracefully
    # see https://www.erlang.org/doc/apps/erts/erlang.html#process_flag/2
    Process.flag(:trap_exit, true)

    last_queried_marker =
      IndexingPipeline.get_processor_marker!(source_module.processor_marker_key(), cache_version)

    initial_state = %{
      last_queried_marker: last_queried_marker |> CacheEntryMarker.from(),
      pulled_records: [],
      acked_records: [],
      cache_version: cache_version,
      stored_demand: 0,
      source_module: source_module
    }

    source_module.init(initial_state)

    {:producer, initial_state}
  end

  @impl GenStage
  @spec handle_demand(integer(), state()) :: {:noreply, list(Broadway.Message.t()), state()}
  def handle_demand(
        demand,
        state = %{
          last_queried_marker: last_queried_marker,
          pulled_records: pulled_records,
          acked_records: acked_records,
          cache_version: cache_version,
          stored_demand: stored_demand,
          source_module: source_module
        }
      ) do
    total_demand = stored_demand + demand

    records =
      source_module.get_cache_entries_since!(last_queried_marker, total_demand, cache_version)

    if last_queried_marker == nil && length(records) > 0 do
      DpulCollections.IndexMetricsTracker.register_fresh_start(source_module, cache_version)
    end

    new_state =
      state
      |> Map.put(
        :last_queried_marker,
        Enum.at(records, -1) |> CacheEntryMarker.from() || last_queried_marker
      )
      |> Map.put(
        :pulled_records,
        Enum.concat(
          pulled_records,
          Enum.map(records, &CacheEntryMarker.from/1)
        )
      )
      |> Map.put(:acked_records, acked_records)
      |> Map.put(:stored_demand, calculate_stored_demand(total_demand, length(records)))

    # Set a timer to try fulfilling demand again later
    # This shouldn't be necessary with the notifications, but is a useful
    # fallback.
    if new_state.stored_demand > 0 do
      DpulCollections.IndexMetricsTracker.register_polling_started(source_module, cache_version)
      Process.send_after(self(), :check_for_updates, 60000)
    end

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  defp calculate_stored_demand(total_demand, fulfilled_demand)
       when total_demand == fulfilled_demand do
    0
  end

  defp calculate_stored_demand(total_demand, fulfilled_demand)
       when total_demand > fulfilled_demand do
    total_demand - fulfilled_demand
  end

  def handle_info(:check_for_updates, state = %{stored_demand: demand}) when demand > 0 do
    new_demand = 0
    handle_demand(new_demand, state)
  end

  def handle_info(:check_for_updates, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  @spec handle_info({atom(), atom(), list(%CacheEntryMarker{})}, state()) ::
          {:noreply, list(Broadway.Message.t()), state()}
  # pending_markers: incoming newly acked markers
  # state.acked_records: previously blocked acked records
  # state.pulled_records: records the db producer has sent in order, waiting to be acked
  def handle_info({:ack, :database_producer_ack, pending_markers}, state) do
    messages = []

    sorted_markers =
      (state.acked_records ++ pending_markers)
      |> Enum.uniq()
      |> Enum.sort(CacheEntryMarker)

    state =
      state
      |> Map.put(:acked_records, sorted_markers)

    {new_state, last_removed_marker} = process_markers(state, nil)

    if last_removed_marker != nil do
      %CacheEntryMarker{timestamp: cache_location, id: cache_record_id} =
        last_removed_marker

      IndexingPipeline.write_processor_marker(%{
        type: state.source_module.processor_marker_key(),
        cache_version: state.cache_version,
        cache_location: cache_location,
        cache_record_id: cache_record_id
      })
    end

    notify_ack(
      pending_markers |> length(),
      new_state.pulled_records |> length(),
      state.source_module.processor_marker_key(),
      state.cache_version
    )

    {:noreply, messages, new_state}
  end

  @impl GenStage
  def handle_cast(
        :start_over,
        state = %{source_module: source_module, cache_version: cache_version}
      ) do
    # Delete the process marker from the db
    indexing_processor_marker =
      IndexingPipeline.get_processor_marker!(source_module.processor_marker_key(), cache_version)

    IndexingPipeline.delete_processor_marker(indexing_processor_marker)
    # stop it to clear out state, supervisor will spin it back up
    {:stop, :normal, state}
  end

  # Updates state, removing any acked_records from pulled_records and returns the
  # last removed marker so it can be saved to the database.
  # If the transformer element of pulled_records is the first element of
  # acked_records, remove it from both and process again.
  @spec process_markers(state(), CacheEntryMarker.t()) ::
          {state, CacheEntryMarker.t() | nil}
  defp process_markers(
         state = %{
           pulled_records: [first_record | pulled_records],
           acked_records: [first_record | acked_records]
         },
         _last_removed_marker
       ) do
    state
    |> Map.put(:pulled_records, pulled_records)
    |> Map.put(:acked_records, acked_records)
    |> process_markers(first_record)
  end

  # Handles the case where the producer crashes, resets pulled_records to an
  # empty list, and then gets a message acknowledgement.
  defp process_markers(
         state = %{pulled_records: [], acked_records: acked_records},
         last_removed_marker
       )
       when length(acked_records) > 0 do
    state
    |> Map.put(:acked_records, [])
    |> process_markers(last_removed_marker)
  end

  defp process_markers(
         state = %{
           pulled_records: [first_pulled_record | _],
           acked_records: [first_acked_record | tail_acked_records]
         },
         last_removed_marker
       ) do
    if CacheEntryMarker.compare(first_acked_record, first_pulled_record) ==
         :lt do
      state
      |> Map.put(:acked_records, tail_acked_records)
      |> process_markers(last_removed_marker)
    else
      {state, last_removed_marker}
    end
  end

  defp process_markers(state, last_removed_marker), do: {state, last_removed_marker}

  @impl Broadway.Acknowledger
  @spec ack({pid(), atom()}, list(Broadway.Message.t()), list(Broadway.Message.t())) :: any()
  def ack({database_producer_pid, :database_producer_ack}, successful, failed) do
    # TODO: Do some error handling
    acked_markers = (successful ++ failed) |> Enum.map(&CacheEntryMarker.from/1)
    send(database_producer_pid, {:ack, :database_producer_ack, acked_markers})
  end

  # This happens when ack is finished, we listen to this telemetry event in
  # tests so we know when the Producer's done processing a message.
  @spec notify_ack(integer(), integer(), String.t(), integer()) :: any()
  @type ack_event_metadata :: %{
          acked_count: integer(),
          unacked_count: integer(),
          processor_marker_key: String.t()
        }
  defp notify_ack(acked_message_count, unacked_count, processor_marker_key, cache_version) do
    :telemetry.execute(
      [:database_producer, :ack, :done],
      %{},
      %{
        acked_count: acked_message_count,
        unacked_count: unacked_count,
        processor_marker_key: processor_marker_key,
        cache_version: cache_version
      }
    )
  end

  @spec wrap_record(record :: HydrationCacheEntry) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :database_producer_ack}, nil}
    }
  end
end
