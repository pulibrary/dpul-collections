defmodule DpulCollections.IndexingPipeline.CoherenceTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Coherence

  test "index_parity?/0 is false when the old index is fresher than the new index" do
    {marker1, marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers(1)
    FiggyTestFixtures.hydration_cache_markers(2)

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 1,
      cache_location: marker2.timestamp,
      cache_record_id: marker2.id
    })

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 2,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    refute Coherence.index_parity?()
  end

  test "index_parity?/0 is true when the new index is fresher than the old index" do
    {marker1, marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers(1)
    FiggyTestFixtures.hydration_cache_markers(2)

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 1,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 2,
      cache_location: marker2.timestamp,
      cache_record_id: marker2.id
    })

    assert Coherence.index_parity?()
  end

  test "index_parity?/0 is true when the new index and the old index have equal freshness" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.hydration_cache_markers(1)
    FiggyTestFixtures.hydration_cache_markers(2)

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 1,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 2,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    assert Coherence.index_parity?()
  end

  test "document_count_report/0" do
    [old_index, new_index] = Solr.Index.write_indexes()

    Solr.Management.create_collection(new_index)
    assert Solr.Management.collection_exists?(new_index)

    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    doc2 = %{
      "id" => "2cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 2"]
    }

    Solr.add([doc, doc2], old_index)
    Solr.soft_commit(old_index)
    Solr.add([doc], new_index)
    Solr.soft_commit(new_index)

    assert Coherence.document_count_report() == [
             %{cache_version: 1, collection: "dpulc1", document_count: 2},
             %{cache_version: 2, collection: "dpulc2", document_count: 1}
           ]

    Solr.Management.delete_collection(new_index)
  end
end
