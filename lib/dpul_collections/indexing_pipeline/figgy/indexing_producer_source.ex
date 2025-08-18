defmodule DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource do
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source

  def processor_marker_key() do
    "figgy_indexer"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, cache_version) do
    entries =
      IndexingPipeline.get_transformation_cache_entries_since!(
        last_queried_marker,
        total_demand,
        cache_version
      )

    if length(entries) > 0 do
      markers = entries |> Enum.map(&CacheEntryMarker.from/1)
    end

    entries
  end
end
