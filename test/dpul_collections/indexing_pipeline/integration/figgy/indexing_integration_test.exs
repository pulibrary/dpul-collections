defmodule DpulCollections.IndexingPipeline.Figgy.IndexingIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    :ok
  end

  def start_indexing_producer(batch_size \\ 1) do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:indexing_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, indexer} =
      Figgy.IndexingConsumer.start_link(
        cache_version: 0,
        producer_module: MockFiggyIndexingProducer,
        producer_options: {self()},
        batch_size: batch_size
      )

    indexer
  end

  test "solr document creation" do
    FiggyTestFixtures.transformation_cache_markers()

    indexer = start_indexing_producer()

    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}

    Solr.commit()
    assert Solr.document_count() == 1

    indexer |> Broadway.stop(:normal)
  end

  test "doesn't override newer solr document versions" do
    # TODO: Think more on this use case
  end

  test "updates existing solr document versions" do
    {marker1, _marker2, _marker3} = FiggyTestFixtures.transformation_cache_markers()

    Solr.add(%{
      "id" => marker1.id,
      "title" => ["old title"]
    })

    # Process that past record.
    indexer = start_indexing_producer()
    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}
    indexer |> Broadway.stop(:normal)
    # Ensure there's only one solr document
    Solr.commit()
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
    assert_receive {:ack_done}
    Solr.commit()
    # Make sure the first record that comes back is what we expect
    doc = Solr.find_by_id(marker2.id)
    assert doc["title_ss"] == ["test title 2"]
    indexer |> Broadway.stop(:normal)
  end
end
