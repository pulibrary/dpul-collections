defmodule DpulCollections.IndexingPipeline.Coherence do
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline

  def index_parity?() do
    pms =
      Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline)
      |> Enum.map(fn pipeline ->
        IndexingPipeline.get_processor_marker!("figgy_indexer", pipeline[:cache_version])
      end)

    version_sorted = Enum.sort_by(pms, & &1.cache_version)
    date_sorted = Enum.sort_by(pms, & &1.cache_location, DateTime)
    version_sorted == date_sorted
  end

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
