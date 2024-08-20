defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Figgy database
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.{FiggyResource, ProcessorMarker}
  use GenStage
  @behaviour Broadway.Acknowledger

  def start_link(cache_version \\ 0) do
    GenStage.start_link(__MODULE__, cache_version)
  end

  @impl GenStage
  @type state :: %{
          last_queried_marker: ProcessorMarker.marker(),
          pulled_records: [ProcessorMarker.marker()],
          acked_records: [ProcessorMarker.marker()],
          cache_version: Integer
        }
  def init(cache_version) do
    last_queried_marker = IndexingPipeline.get_hydrator_marker(cache_version)

    initial_state = %{
      last_queried_marker: last_queried_marker |> ProcessorMarker.to_marker(),
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
    records = IndexingPipeline.get_figgy_resources_since!(last_queried_marker, demand)

    new_state =
      state
      |> Map.put(
        :last_queried_marker,
        Enum.at(records, -1) |> ProcessorMarker.to_marker() || last_queried_marker
      )
      |> Map.put(
        :pulled_records,
        Enum.concat(pulled_records, Enum.map(records, &ProcessorMarker.to_marker/1))
      )
      |> Map.put(:acked_records, acked_records)

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  @impl GenStage
  def handle_info({:ack, :figgy_producer_ack, pending_markers}, state) do
    messages = []

    state = %{
      state
      | acked_records:
          :ordsets.from_list(state.acked_records ++ pending_markers) |> Enum.sort(ProcessorMarker)
    }

    {new_state, last_removed_marker} = process_markers(state, nil)

    if last_removed_marker != nil do
      {cache_location, cache_record_id} = last_removed_marker
      IndexingPipeline.write_hydrator_marker(state.cache_version, cache_location, cache_record_id)
    end

    notify_ack(pending_markers |> length())
    {:noreply, messages, new_state}
  end

  # Updates state, removing any acked_records from pulled_records and returns the
  # last removed marker so it can be saved to the database.
  # If the first element of pulled_records is the first element of
  # acked_records, remove it from both and process again.
  @spec process_markers(state(), ProcessorMarker.marker()) :: {state, ProcessorMarker.marker()}
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

  defp process_markers(
         state = %{pulled_records: [], acked_records: acked_records},
         last_removed_marker
       )
       when length(acked_records) > 0 do
    state
    |> Map.put(:acked_records, [])
    |> process_markers(last_removed_marker)
  end

  defp process_markers(state, last_removed_marker), do: {state, last_removed_marker}

  @impl Broadway.Acknowledger
  def ack({pid, :figgy_producer_ack}, successful, failed) do
    # Do some error handling
    acked_markers = (successful ++ failed) |> Enum.map(&ProcessorMarker.to_marker/1)
    send(pid, {:ack, :figgy_producer_ack, acked_markers})
  end

  defp notify_ack(acked_message_count) do
    :telemetry.execute(
      [:figgy_producer, :ack, :done],
      %{},
      %{acked_count: acked_message_count}
    )
  end

  # TODO: Function to reset current index version's saved marker, i.e. full reindex

  @spec wrap_record(record :: FiggyResource) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :figgy_producer_ack}, nil}
    }
  end
end
