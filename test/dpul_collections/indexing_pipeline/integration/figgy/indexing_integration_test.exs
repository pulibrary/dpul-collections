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
    {marker1, _marker2, _marker3} = FiggyTestFixtures.transformation_cache_markers()

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

    Solr.add(
      %{
        "id" => marker1.id,
        "title" => ["old title"]
      }
    )

    # Process that past record.
    indexer = start_indexing_producer()
    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}
    indexer |> Broadway.stop(:normal)
    # Ensure there's only one solr document
    Solr.commit()
    assert Solr.document_count() == 1
    # Ensure that entry has the new title
    # doc = Solr.get(marker1.id)
    # assert doc["title_ss"] == ["test title 1"]
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
    # Make sure the first record that comes back is what we expect
    cache_entry = IndexingPipeline.list_transformation_cache_entries() |> hd
    assert cache_entry.record_id == marker2.id
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == marker2.timestamp
    indexer |> Broadway.stop(:normal)
  end

  test "doesn't process non-figgy transformation cache entries" do
    IndexingPipeline.write_transformation_cache_entry(%{
      cache_version: 0,
      record_id: "some-other-id",
      source_cache_order: ~U[2100-03-09 20:19:33.414040Z],
      data: %{
        "non_figgy_property" => "stuff"
      }
    })

    # Process that past record.
    indexer = start_indexing_producer()
    MockFiggyIndexingProducer.process(1)
    assert_receive {:ack_done}
    indexer |> Broadway.stop(:normal)
    # Ensure there are no transformation cache entries.
    entries = IndexingPipeline.list_transformation_cache_entries()
    assert length(entries) == 0
  end
end
