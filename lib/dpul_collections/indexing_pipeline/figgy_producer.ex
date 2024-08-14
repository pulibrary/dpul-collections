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
  def handle_info({:ack, :figgy_producer_ack, successful_messages, failed_messages}, state) do
    messages = []

    notify_ack(successful_messages |> length(), failed_messages |> length())
    {:noreply, messages, state}
  end

  defp notify_ack(successful_message_count, failed_message_count) do
    :telemetry.execute(
      [:figgy_producer, :ack, :done],
      %{},
      %{success_count: successful_message_count, failed_count: failed_message_count}
    )
  end

  defp marker(nil) do
    nil
  end

  defp marker(record = %FiggyResource{}) do
    {record.updated_at, record.id}
  end

  # TODO: Function to reset current index version's saved marker
  # TODO: Function to save a marker to the db for a given index version (part
  #    of ack)

  @spec wrap_record(record :: FiggyResource) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: Broadway.CallerAcknowledger.init({self(), :figgy_producer_ack}, :ignored)
    }
  end
end
