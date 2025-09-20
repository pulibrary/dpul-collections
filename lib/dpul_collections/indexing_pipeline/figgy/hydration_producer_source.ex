defmodule DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source
  def processor_marker_key() do
    "figgy_hydrator"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, cache_version, max_time \\ nil)

  def get_cache_entries_since!(last_queried_marker, total_demand, _cache_version, max_time) do
    IndexingPipeline.get_figgy_resources_since!(
      last_queried_marker,
      max(total_demand, 100),
      max_time
    )
  end

  def get_max_bound_timestamp do
    IndexingPipeline.get_latest_figgy_resource_marker!().timestamp
  end

  def init(_producer_state) do
  end
end
