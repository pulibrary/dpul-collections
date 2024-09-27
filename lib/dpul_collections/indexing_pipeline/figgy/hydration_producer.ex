defmodule DpulCollections.IndexingPipeline.Figgy.HydrationProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Figgy database
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  use GenStage
  @behaviour Broadway.Acknowledger

  def start_link(cache_version \\ 0) do
    GenStage.start_link(__MODULE__, cache_version)
  end

  @impl GenStage
  @type state :: %{
          last_queried_marker: Figgy.ResourceMarker.t(),
          pulled_records: [Figgy.ResourceMarker.t()],
          acked_records: [Figgy.ResourceMarker.t()],
          cache_version: Integer,
          stored_demand: Integer
        }
  def init(cache_version) do
    last_queried_marker = IndexingPipeline.get_processor_marker!("figgy_hydrator", cache_version)

    initial_state = %{
      last_queried_marker: last_queried_marker |> Figgy.ResourceMarker.from(),
      pulled_records: [],
      acked_records: [],
      cache_version: cache_version,
      stored_demand: 0
    }

    {:producer, initial_state}
  end

  @impl GenStage
  def handle_demand(
        demand,
        state = %{
          last_queried_marker: last_queried_marker,
          pulled_records: pulled_records,
          acked_records: acked_records,
          stored_demand: stored_demand
        }
      ) do
    total_demand = stored_demand + demand

    records = IndexingPipeline.get_figgy_resources_since!(last_queried_marker, total_demand)

    new_state =
      state
      |> Map.put(
        :last_queried_marker,
        Enum.at(records, -1) |> Figgy.ResourceMarker.from() || last_queried_marker
      )
      |> Map.put(
        :pulled_records,
        Enum.concat(pulled_records, Enum.map(records, &Figgy.ResourceMarker.from/1))
      )
      |> Map.put(:acked_records, acked_records)
      |> Map.put(:stored_demand, calculate_stored_demand(total_demand, length(records)))

    # Set a timer to try fulfilling demand again later
    if new_state.stored_demand > 0 do
      Process.send_after(
        self(),
        :check_for_updates,
        Application.get_env(:dpul_collections, :figgy_hydrator)[:poll_interval]
      )
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

  def handle_info(:check_for_updates, state = %{stored_demand: demand})
      when demand > 0 do
    new_demand = 0
    handle_demand(new_demand, state)
  end

  def handle_info(:check_for_updates, state) do
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info({:ack, :figgy_producer_ack, pending_markers}, state) do
    messages = []

    sorted_markers =
      (state.acked_records ++ pending_markers)
      |> Enum.uniq()
      |> Enum.sort(Figgy.ResourceMarker)

    state =
      state
      |> Map.put(:acked_records, sorted_markers)

    {new_state, last_removed_marker} = process_markers(state, nil)

    if last_removed_marker != nil do
      %Figgy.ResourceMarker{timestamp: cache_location, id: cache_record_id} = last_removed_marker

      IndexingPipeline.write_processor_marker(%{
        type: "figgy_hydrator",
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
  # If the first element of pulled_records is the first element of
  # acked_records, remove it from both and process again.
  @spec process_markers(state(), Figgy.ResourceMarker.t()) :: {state, Figgy.ResourceMarker.t()}
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
    if Figgy.ResourceMarker.compare(first_acked_record, first_pulled_record) == :lt do
      state
      |> Map.put(:acked_records, tail_acked_records)
      |> process_markers(last_removed_marker)
    else
      {state, last_removed_marker}
    end
  end

  defp process_markers(state, last_removed_marker), do: {state, last_removed_marker}

  @impl Broadway.Acknowledger
  def ack({figgy_producer_pid, :figgy_producer_ack}, successful, failed) do
    # TODO: Do some error handling
    acked_markers = (successful ++ failed) |> Enum.map(&Figgy.ResourceMarker.from/1)
    send(figgy_producer_pid, {:ack, :figgy_producer_ack, acked_markers})
  end

  # This happens when ack is finished, we listen to this telemetry event in
  # tests so we know when the Hydrator's done processing a message.
  defp notify_ack(acked_message_count) do
    :telemetry.execute(
      [:figgy_producer, :ack, :done],
      %{},
      %{acked_count: acked_message_count}
    )
  end

  # TODO: Function to reset current index version's saved marker, i.e. full reindex

  @spec wrap_record(record :: Figgy.Resource) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :figgy_producer_ack}, nil}
    }
  end
end
