defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  alias DpulCollections.IndexingPipeline
  use GenStage

  def start_link(number) do
    GenStage.start_link(__MODULE__, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, state) when demand > 0 do
    records = IndexingPipeline.get_figgy_resources_since!(~U[1900-01-01 00:00:00Z], 1)
    {:noreply, records, state}
  end
end
