defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Figgy database
  """

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.FiggyResource
  use GenStage

  def start_link(number) do
    GenStage.start_link(__MODULE__, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, %{last_queried_marker: nil}) when demand > 0 do
    records = IndexingPipeline.get_figgy_resources_since!(nil, demand)

    new_state = %{
      last_queried_marker: Enum.at(records, -1) |> marker,
      pulled_records: Enum.map(records, &marker/1),
      acked_records: []
    }

    {:noreply, records, new_state}
  end

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

    {:noreply, records, new_state}
  end

  defp marker(record = %FiggyResource{}) do
    {record.updated_at, record.id}
  end
end
