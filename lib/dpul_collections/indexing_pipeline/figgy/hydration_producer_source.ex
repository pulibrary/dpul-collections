defmodule DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source
  def processor_marker_key() do
    "figgy_hydrator"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, _cache_version) do
    IndexingPipeline.get_figgy_resources_since!(last_queried_marker, max(total_demand, 500))
  end

  def init(_producer_state) do
  end
end
