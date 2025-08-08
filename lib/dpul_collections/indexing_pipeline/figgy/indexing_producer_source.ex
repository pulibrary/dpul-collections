defmodule DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source

  def init() do
  end

  def processor_marker_key() do
    "figgy_indexer"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, cache_version) do
    IndexingPipeline.get_transformation_cache_entries_since!(
      last_queried_marker,
      total_demand,
      cache_version
    )
  end
end
