defmodule DpulCollections.IndexingPipeline.CoherenceTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline.Coherence
  import SolrTestSupport

  setup do
    Solr.delete_all(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  setup context do
    if cache_settings = context[:cache_settings] do
      Application.put_env(:dpul_collections, DpulCollections.IndexingPipeline, cache_settings)

      on_exit(fn ->
        Application.delete_env(:dpul_collections, DpulCollections.IndexingPipeline)
      end)
    end

    :ok
  end

  @tag cache_settings: [
         [cache_version: 1, write_collection: "dpulc1"],
         [
           cache_version: 2,
           write_collection: "dpulc2"
         ]
       ]
  test "document_count_report" do
    new_collection = "dpulc2"
    Solr.create_collection(new_collection)

    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    doc2 = %{
      "id" => "2cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 2"]
    }

    Solr.add([doc, doc2], active_collection())
    Solr.commit(active_collection())
    Solr.add([doc], new_collection)
    Solr.commit(new_collection)

    assert Coherence.document_count_report() == [
             %{cache_version: 1, collection: "dpulc1", document_count: 2},
             %{cache_version: 2, collection: "dpulc2", document_count: 1}
           ]

    Solr.delete_collection(new_collection)
  end
end
