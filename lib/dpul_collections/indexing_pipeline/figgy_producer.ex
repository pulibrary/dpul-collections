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
    initial_state = %{last_queried_marker: nil}
    {:producer, initial_state}
  end

  # TODO: Function to reset current index version's saved marker
  # TODO: Function to save a marker to the db for a given index version (part
  #    of ack)

  @impl GenStage
  def handle_demand(demand, %{last_queried_marker: nil}) when demand > 0 do
    records = IndexingPipeline.get_figgy_resources_since!(nil, demand)

    new_state = %{
      last_queried_marker: Enum.at(records, -1) |> marker,
      pulled_records: Enum.map(records, &marker/1),
      acked_records: []
    }

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
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
      last_queried_marker: Enum.at(records, -1) |> marker,
      pulled_records: Enum.concat(pulled_records, Enum.map(records, &marker/1)),
      acked_records: acked_records
    }

    {:noreply, Enum.map(records, &wrap_record/1), new_state}
  end

  defp marker(record = %FiggyResource{}) do
    {record.updated_at, record.id}
  end

  @spec wrap_record(record :: FiggyResource) :: Broadway.Message.t()
  defp wrap_record(record) do
    %Broadway.Message{
      data: record,
      acknowledger: {__MODULE__, :figgy_producer_ack, :unused_ack_data}
    }
  end
end
