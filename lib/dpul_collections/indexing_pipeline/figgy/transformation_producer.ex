defmodule DpulCollections.IndexingPipeline.Figgy.TransformationProducer do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source

  def processor_marker_key() do
    "figgy_transformer"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand) do
    IndexingPipeline.get_hydration_cache_entries_since!(last_queried_marker, total_demand)
  end
end
