defmodule DpulCollections.Utilities do
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  def reindex_solr(cache_version) do
    indexing_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_indexer", cache_version)

    IndexingPipeline.delete_processor_marker(indexing_processor_marker)
    # When the consumer is stopped, it supervisor restarts it immediately.
    # This resets the state and last queried marker.
    GenServer.stop(Figgy.IndexingConsumer)
  end

  def reindex_transformation_cache(cache_version) do
    transformation_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_transformer", cache_version)

    IndexingPipeline.delete_processor_marker(transformation_processor_marker)
    GenServer.stop(Figgy.TransformationConsumer)
  end

  def reindex_hydration_cache(cache_version) do
    hydration_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_hydrator", cache_version)

    IndexingPipeline.delete_processor_marker(hydration_processor_marker)
    GenServer.stop(Figgy.HydrationConsumer)
  end

  def reindex_all(cache_version) do
    reindex_hydration_cache(cache_version)
    reindex_transformation_cache(cache_version)
    reindex_solr(cache_version)
  end
end
