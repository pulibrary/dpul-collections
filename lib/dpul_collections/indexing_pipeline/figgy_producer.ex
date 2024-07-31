defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  alias DpulCollections.IndexingPipeline
  use GenStage

  def start_link(number) do
    GenStage.start_link(__MODULE__, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, %{last_queried_marker: nil}) when demand > 0 do
    records = IndexingPipeline.get_figgy_resources_since!(~N[1900-01-01 00:00:00], demand)

    new_state = %{
      last_queried_marker: Enum.at(records, 0).updated_at,
      pulled_records: [Enum.at(records, 0).id],
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
      last_queried_marker: Enum.at(records, -1).updated_at,
      pulled_records:
        Enum.concat(pulled_records, Enum.map(records, fn r -> r.id end)) |> Enum.uniq(),
      acked_records: acked_records
    }

    {:noreply, records, new_state}
  end
end
