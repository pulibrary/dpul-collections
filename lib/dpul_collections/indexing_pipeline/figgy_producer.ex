defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Figgy database
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.FiggyResource
  use GenStage

  def start_link(index_version \\ 0) do
    GenStage.start_link(__MODULE__, index_version, name: __MODULE__)
  end

  @impl GenStage
  def init(_index_version) do
    ## TODO: Set last_queried_marker if it's found in the database
    # Pass index_version, check db for marker, if it's not found we create one
    # with the index_version and nil? Or just start it with last_queried_marker
    # nil.
    initial_state = %{
      last_queried_marker: nil,
      pulled_records: [],
      acked_records: []
    }

    {:producer, initial_state}
  end

  @impl GenStage
  def handle_demand(demand, %{
        last_queried_marker: last_queried_marker,
        pulled_records: pulled_records,
        acked_records: acked_records
      })
      when demand > 0 do
    records = IndexingPipeline.get_figgy_resources_since!(last_queried_marker, demand)

    new_state = %{
      last_queried_marker: Enum.at(records, -1) |> marker || last_queried_marker,
      pulled_records: Enum.concat(pulled_records, Enum.map(records, &marker/1)),
      acked_records: acked_records
    }

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  @impl GenStage
  def handle_info({:ack, :figgy_producer_ack, acked_markers}, state) do
    messages = []

    notify_ack(acked_markers |> length())
    {:noreply, messages, state}
  end

  def ack({pid, :figgy_producer_ack}, successful, failed) do
    # Do some error handling
    acked_markers = (successful ++ failed) |> Enum.map(&marker/1) |> Enum.sort()
    send(pid, {:ack, :figgy_producer_ack, acked_markers})
  end

  defp notify_ack(acked_message_count) do
    :telemetry.execute(
      [:figgy_producer, :ack, :done],
      %{},
      %{acked_count: acked_message_count}
    )
  end

  defp marker(nil) do
    nil
  end

  defp marker(record = %FiggyResource{}) do
    {record.updated_at, record.id}
  end

  defp marker(%Broadway.Message{data: data}) do
    marker(data)
  end

  # TODO: Function to reset current index version's saved marker
  # TODO: Function to save a marker to the db for a given index version (part
  #    of ack)

  @spec wrap_record(record :: FiggyResource) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, {self(), :figgy_producer_ack}, nil}
    }
  end
end
