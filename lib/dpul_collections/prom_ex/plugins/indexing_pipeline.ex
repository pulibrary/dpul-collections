# This plugin converts Sibyl telemetry events into PromEx events.
defmodule DpulCollections.PromEx.Plugins.IndexingPipeline do
  use PromEx.Plugin
  @query_event [:dpul_collections, :indexing_pipeline, :query]
  # All function names with arity that we want to convert to PromEx metrics for
  # Prometheus.
  @query_functions [
    :"get_figgy_resource!/1",
    :"get_figgy_parents/1",
    :"get_figgy_resources/1",
    :"get_figgy_resources_since!/3",
    :"get_related_hydration_cache_record_ids!/3"
  ]

  @impl true
  def event_metrics(_opts) do
    set_up_telemetry_proxy()

    Event.build(
      :indexing_pipeline_metrics,
      distribution(
        [
          :dpul_collections,
          :indexing_pipeline,
          :query,
          :duration,
          :milliseconds
        ],
        event_name: @query_event,
        measurement: :duration,
        description: "Time for query to return",
        reporter_options: [
          buckets: [10, 50, 250, 2_500, 10_000, 30_000]
        ],
        tags: [:function],
        unit: {:native, :millisecond}
      )
    )
  end

  def handle_proxy_query_event(_event_name, event_measurement, event_metadata, _config) do
    :telemetry.execute(@query_event, event_measurement, event_metadata)
  end

  # Sibyl sends events like [:dpul_collections, :indexing_pipeline,
  # "get_figgy_parents/1", :stop], but we want to combine all those events into
  # a single event with function as metadata. To do that we capture those events
  # and send a new telemetry event (@query_event) which is what we actually forward to PromEx.
  defp set_up_telemetry_proxy() do
    @query_functions
    |> Enum.each(fn func_name ->
      query_event = [:dpul_collections, :indexing_pipeline, func_name, :stop]

      :telemetry.attach(
        [:prom_ex, :indexing_pipeline, :proxy] ++ func_name,
        query_event,
        &__MODULE__.handle_proxy_query_event/4,
        %{}
      )
    end)
  end
end
