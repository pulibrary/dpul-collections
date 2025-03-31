defmodule DpulCollections.PromEx.Plugins.IndexingPipeline do
  use PromEx.Plugin

  @impl true
  def event_metrics(opts) do
    Event.build(
      :indexing_pipeline_metrics,
      [
        :"get_figgy_resource!/1",
        :"get_figgy_parents/1",
        :"get_figgy_resources/2",
        :"get_figgy_resources_since!/2"
      ]
      |> Enum.map(fn func_name ->
        distribution(
          [
            :dpul_collections,
            :indexing_pipeline,
            :query,
            :duration,
            :milliseconds
          ],
          event_name: [:dpul_collections, :indexing_pipeline, func_name, :stop],
          measurement: :duration,
          description: "Time for #{func_name} to return",
          reporter_options: [
            buckets: [10, 50, 250, 2_500, 10_000, 30_000]
          ],
          tags: [:function],
          unit: {:native, :millisecond}
        )
      end)
    )
  end
end
