defmodule DpulCollections.IndexingPipeline.Coherence do
  alias DpulCollections.Solr

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
