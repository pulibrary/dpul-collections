defmodule DpulCollections.IndexingPipeline.FiggyProducer do
  use GenStage

  def start_link(number) do
    GenStage.start_link(__MODULE__, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, state) when demand > 0 do
    records = [%{id: "3cb7627b-defc-401b-9959-42ebc4488f74"}]
    {:noreply, records, state}
  end
end
