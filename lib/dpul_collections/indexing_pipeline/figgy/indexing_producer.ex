defmodule DpulCollections.IndexingPipeline.Figgy.IndexingProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Transformation Cache.
  """
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  use GenStage
  @behaviour Broadway.Acknowledger

  @spec start_link(integer()) :: Broadway.on_start()
  def start_link(cache_version \\ 0) do
    GenStage.start_link(__MODULE__, cache_version)
  end

  @impl GenStage
  @type state :: %{
          last_queried_marker: Figgy.TransformationCacheEntryMarker.t(),
          pulled_records: [Figgy.TransformationCacheEntryMarker.t()],
          acked_records: [Figgy.TransformationCacheEntryMarker.t()],
          cache_version: Integer
        }
  @spec init(integer()) :: {:producer, state()}
  def init(cache_version) do
    last_queried_marker =
      IndexingPipeline.get_processor_marker!("indexer", cache_version)

    initial_state = %{
      last_queried_marker: last_queried_marker |> Figgy.TransformationCacheEntryMarker.from(),
      pulled_records: [],
      acked_records: [],
      cache_version: cache_version
    }

    {:producer, initial_state}
  end

  @impl GenStage
  @spec handle_demand(integer(), state()) :: {:noreply, list(Broadway.Message.t()), state()}
  def handle_demand(
        demand,
        state = %{
          last_queried_marker: last_queried_marker,
          pulled_records: pulled_records,
          acked_records: acked_records
        }
      )
      when demand > 0 do
    records =
      IndexingPipeline.get_transformation_cache_entries_since!(last_queried_marker, demand)

    new_state =
      state
      |> Map.put(
        :last_queried_marker,
        Enum.at(records, -1) |> Figgy.TransformationCacheEntryMarker.from() || last_queried_marker
      )
      |> Map.put(
        :pulled_records,
        Enum.concat(
          pulled_records,
          Enum.map(records, &Figgy.TransformationCacheEntryMarker.from/1)
        )
      )
      |> Map.put(:acked_records, acked_records)

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  @impl GenStage
  @spec handle_info({atom(), atom(), list(%Figgy.TransformationCacheEntryMarker{})}, state()) ::
          {:noreply, list(Broadway.Message.t()), state()}
  def handle_info({:ack, :indexing_producer_ack, pending_markers}, state) do
    messages = []

    sorted_markers =
      (state.acked_records ++ pending_markers)
      |> Enum.uniq()
      |> Enum.sort(Figgy.TransformationCacheEntryMarker)

    state =
      state
      |> Map.put(:acked_records, sorted_markers)

    {new_state, last_removed_marker} = process_markers(state, nil)

    if last_removed_marker != nil do
      %Figgy.TransformationCacheEntryMarker{timestamp: cache_location, id: cache_record_id} =
        last_removed_marker

      IndexingPipeline.write_processor_marker(%{
        type: "indexer",
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
  # If the indexer element of pulled_records is the first element of
  # acked_records, remove it from both and process again.
  @spec process_markers(state(), Figgy.TransformationCacheEntryMarker.t()) ::
          {state, Figgy.TransformationCacheEntryMarker.t()}
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
    if Figgy.TransformationCacheEntryMarker.compare(first_acked_record, first_pulled_record) ==
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
  def ack({indexing_producer_pid, :indexing_producer_ack}, successful, failed) do
    # TODO: Do some error handling
    acked_markers =
      (successful ++ failed) |> Enum.map(&Figgy.TransformationCacheEntryMarker.from/1)

    send(indexing_producer_pid, {:ack, :indexing_producer_ack, acked_markers})
  end

  # This happens when ack is finished, we listen to this telemetry event in
  # tests so we know when the Indexer is done processing a message.
  @spec notify_ack(integer()) :: any()
  defp notify_ack(acked_message_count) do
    :telemetry.execute(
      [:indexing_producer, :ack, :done],
      %{},
      %{acked_count: acked_message_count}
    )
  end

  @spec wrap_record(record :: Figgy.TransformationCacheEntry) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :indexing_producer_ack}, nil}
    }
  end
end
