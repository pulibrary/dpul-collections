defmodule DpulCollections.IndexingPipeline.Figgy.IndexingProducer do
  @moduledoc """
  GenStage Producer that pulls records from the Transformation Cache.
  """
  alias DpulCollections.IndexingPipeline

  def processor_marker_key() do
    "figgy_indexer"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand) do
    IndexingPipeline.get_transformation_cache_entries_since!(last_queried_marker, total_demand)
  end
end
