defmodule DpulCollections.IndexingPipeline.Figgy.IndexingIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr
  alias DpulCollections.Solr.Index

  def start_indexing_producer(cache_version \\ 0) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:database_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, indexer} =
      Figgy.IndexingConsumer.start_link(
        cache_version: cache_version,
        producer_module: MockFiggyIndexingProducer,
        producer_options: {self(), cache_version},
        batch_size: 1,
        solr_index: active_collection()
      )

    indexer
  end

  test "solr document creation" do
    FiggyTestFixtures.transformation_cache_markers()

    indexer = start_indexing_producer()

    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}, 500

    Solr.soft_commit(active_collection())
    assert Solr.document_count() == 1

    indexer |> Broadway.stop(:normal)
  end

  test "when cache version > 0, processor marker cache version is correct" do
    FiggyTestFixtures.transformation_cache_markers(1)

    cache_version = 1
    indexer = start_indexing_producer(cache_version)

    MockFiggyIndexingProducer.process(1, cache_version)
    assert_receive {:ack_done}, 500

    processor_marker = IndexingPipeline.get_processor_marker!("figgy_indexer", cache_version)
    assert processor_marker.cache_version == cache_version

    indexer |> Broadway.stop(:normal)
  end

  test "doesn't override newer solr document versions" do
    # TODO: Think more on this use case
  end

  test "updates existing solr document versions" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.transformation_cache_markers()

    Solr.add(
      [
        %{
          "id" => marker1.id,
          "title_txtm" => ["old title"]
        }
      ],
      active_collection()
    )

    # Process that past record.
    indexer = start_indexing_producer()
    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}, 500
    indexer |> Broadway.stop(:normal)
    # Ensure there's only one solr document
    Solr.soft_commit(active_collection())
    assert Solr.document_count() == 1
    # Ensure that entry has the new title
    doc = Solr.find_by_id(marker1.id)
    assert doc["title_ss"] == ["test title 1"]
  end

  test "loads a marker from the database on startup" do
    {marker1, marker2, _marker3} = FiggyTestFixtures.transformation_cache_markers()

    # Create a marker
    IndexingPipeline.write_processor_marker(%{
      type: "figgy_indexer",
      cache_version: 0,
      cache_location: marker1.timestamp,
      cache_record_id: marker1.id
    })

    # Start the producer
    indexer = start_indexing_producer()
    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}, 500
    Solr.soft_commit(active_collection())
    # Make sure the first record that comes back is what we expect
    doc = Solr.find_by_id(marker2.id)
    assert doc["title_ss"] == ["test title 2"]
    indexer |> Broadway.stop(:normal)
  end

  test "it creates the solr collection" do
    cache_version = 0
    new_index = %Index{(%Index{} = active_collection()) | collection: "new_index1"}
    assert Solr.Management.collection_exists?(new_index) == false

    {:ok, indexer} =
      Figgy.IndexingConsumer.start_link(
        cache_version: cache_version,
        producer_module: MockFiggyIndexingProducer,
        producer_options: {self(), cache_version},
        batch_size: 1,
        solr_index: new_index
      )

    assert Solr.Management.collection_exists?(new_index) == true

    indexer |> Broadway.stop(:normal)
    Solr.Management.delete_collection(new_index)
  end
end
