defmodule DpulCollections.IndexingPipeline.DatabaseProducer.Source do
  alias DpulCollections.IndexingPipeline.Figgy.CacheEntryMarker

  @doc """
  Uniquely identifiable key for this data source. It will be used as the `type`
  field for a ProcessorMarker.
  """
  @callback processor_marker_key() :: (key :: String.t())

  @doc """
  Query that returns a list of entries from a given CacheEntryMarker, up to the
  total_demand. Anything returned by this should be able to be transformed to
  a CacheEntryMarker via CacheEntryMarker.from/1
  """
  @callback get_cache_entries_since!(last_queried_marker :: CacheEntryMarker.t(), total_demand :: integer) :: list(struct)
end
