defmodule DpulCollections.IndexingPipeline.TransformerProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Hyrdation Cache.
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.HydrationCacheEntryMarker
  use GenStage
  @behaviour Broadway.Acknowledger

  def start_link(cache_version \\ 0) do
    GenStage.start_link(__MODULE__, cache_version)
  end

  @impl GenStage
  @type state :: %{
          last_queried_marker: HydrationCacheEntryMarker.t(),
          pulled_records: [HydrationCacheEntryMarker.t()],
          acked_records: [HydrationCacheEntryMarker.t()],
          cache_version: Integer
        }
  def init(cache_version) do
    last_queried_marker = IndexingPipeline.get_processor_marker!("transformer", cache_version)

    initial_state = %{
      last_queried_marker: last_queried_marker |> HydrationCacheEntryMarker.from(),
      pulled_records: [],
      acked_records: [],
      cache_version: cache_version
    }

    {:producer, initial_state}
  end

  @impl GenStage
  def handle_demand(
        demand,
        state = %{
          last_queried_marker: last_queried_marker,
          pulled_records: pulled_records,
          acked_records: acked_records
        }
      )
      when demand > 0 do
    records = IndexingPipeline.get_hydration_cache_entries_since!(last_queried_marker, demand)

    new_state =
      state
      |> Map.put(
        :last_queried_marker,
        Enum.at(records, -1) |> HydrationCacheEntryMarker.from() || last_queried_marker
      )
      |> Map.put(
        :pulled_records,
        Enum.concat(pulled_records, Enum.map(records, &HydrationCacheEntryMarker.from/1))
      )
      |> Map.put(:acked_records, acked_records)

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  @impl GenStage
  def handle_info({:ack, :transformer_producer_ack, pending_markers}, state) do
    messages = []

    sorted_markers =
      (state.acked_records ++ pending_markers)
      |> Enum.uniq()
      |> Enum.sort(HydrationCacheEntryMarker)

    state =
      state
      |> Map.put(:acked_records, sorted_markers)

    {new_state, last_removed_marker} = process_markers(state, nil)

    if last_removed_marker != nil do
      %HydrationCacheEntryMarker{timestamp: cache_location, id: cache_record_id} =
        last_removed_marker

      IndexingPipeline.write_processor_marker(%{
        type: "transformer",
        cache_version: state.cache_version,
        cache_location: cache_location,
        cache_record_id: cache_record_id
      })
    end

    notify_ack(pending_markers |> length())
    {:noreply, messages, new_state}
  end

  # Updates state, removing any acked_records from pulled_records and returns the
  # last removed marker so it can be saved to the database.
  # If the transformer element of pulled_records is the first element of
  # acked_records, remove it from both and process again.
  @spec process_markers(state(), HydrationCacheEntryMarker.t()) ::
          {state, HydrationCacheEntryMarker.t()}
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
    if HydrationCacheEntryMarker.compare(first_acked_record, first_pulled_record) == :lt do
      state
      |> Map.put(:acked_records, tail_acked_records)
      |> process_markers(last_removed_marker)
    else
      {state, last_removed_marker}
    end
  end

  defp process_markers(state, last_removed_marker), do: {state, last_removed_marker}

  @impl Broadway.Acknowledger
  def ack({transformer_producer_pid, :transformer_producer_ack}, successful, failed) do
    # TODO: Do some error handling
    acked_markers = (successful ++ failed) |> Enum.map(&HydrationCacheEntryMarker.from/1)
    send(transformer_producer_pid, {:ack, :transformer_producer_ack, acked_markers})
  end

  # This happens when ack is finished, we listen to this telemetry event in
  # tests so we know when the Hydrator's done processing a message.
  defp notify_ack(acked_message_count) do
    :telemetry.execute(
      [:transformer_producer, :ack, :done],
      %{},
      %{acked_count: acked_message_count}
    )
  end

  @spec wrap_record(record :: HydratorCacheEntry) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :transformer_producer_ack}, nil}
    }
  end
end
