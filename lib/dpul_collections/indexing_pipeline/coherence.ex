defmodule DpulCollections.IndexingPipeline.Coherence do
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline

  @spec index_parity?() :: boolean()
  def index_parity?() do
    pms =
      Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline)
      |> Enum.map(fn pipeline ->
        IndexingPipeline.get_processor_marker!("figgy_indexer", pipeline[:cache_version])
      end)

    # the cache_location in a processor marker isn't consistent between
    # cache versions -- it's just a timestamp. So we pull the hydration
    # cache entries and compare them based on the figgy timestamp itself
    hydration_entries =
      pms
      |> Enum.map(fn marker ->
        IndexingPipeline.get_hydration_cache_entry!(marker.cache_record_id, marker.cache_version)
      end)

    version_sorted = Enum.sort_by(hydration_entries, & &1.cache_version)
    date_sorted = Enum.sort_by(hydration_entries, & &1.source_cache_order, DateTime)
    version_sorted == date_sorted
  end

  @spec document_count_report() :: map()
  def document_count_report() do
    Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline)
    |> Enum.map(fn pipeline ->
      %{
        cache_version: pipeline[:cache_version],
        collection: pipeline[:write_collection],
        document_count: Solr.document_count(pipeline[:write_collection])
      }
    end)
  end
end
