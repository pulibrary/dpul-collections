defmodule DpulCollections.IndexingPipeline.FiggyFullIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.Repo
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    :ok
  end

  def wait_for_index_completion() do
    transformation_cache_entries = IndexingPipeline.list_transformation_cache_entries() |> length
    ephemera_folder_count = FiggyTestSupport.ephemera_folder_count()

    continue =
      if transformation_cache_entries == ephemera_folder_count do
        DpulCollections.Solr.commit()

        if DpulCollections.Solr.document_count() == transformation_cache_entries do
          true
        end
      end

    continue || (:timer.sleep(100) && wait_for_index_completion())
  end

  def wait_for_indexed_count(count) do
    DpulCollections.Solr.commit()
    continue =
        if DpulCollections.Solr.document_count() == count do
          true
        else
          false
        end
    continue || (:timer.sleep(100) && wait_for_indexed_count(count))
  end

  test "a full hydrator and transformer run" do
    # Start the figgy producer
    {:ok, indexer} = Figgy.IndexingConsumer.start_link(cache_version: 1, batch_size: 50)
    {:ok, transformer} = Figgy.TransformationConsumer.start_link(cache_version: 1, batch_size: 50)
    {:ok, hydrator} = Figgy.HydrationConsumer.start_link(cache_version: 1, batch_size: 50)

    task =
      Task.async(fn -> wait_for_index_completion() end)

    Task.await(task, 15000)

    # the hydrator pulled all ephemera folders and terms
    entry_count = Repo.aggregate(Figgy.HydrationCacheEntry, :count)
    assert FiggyTestSupport.total_resource_count() == entry_count

    # the transformer only processes ephemera folders
    transformation_cache_entry_count = Repo.aggregate(Figgy.TransformationCacheEntry, :count)
    assert FiggyTestSupport.ephemera_folder_count() == transformation_cache_entry_count

    # indexed all the documents
    assert Solr.document_count() == transformation_cache_entry_count

    # Ensure that the processor markers have the correct cache version
    hydration_processor_marker = IndexingPipeline.get_processor_marker!("figgy_hydrator", 1)

    transformation_processor_marker =
      IndexingPipeline.get_processor_marker!("figgy_transformer", 1)

    indexing_processor_marker = IndexingPipeline.get_processor_marker!("figgy_indexer", 1)
    assert hydration_processor_marker.cache_version == 1
    assert transformation_processor_marker.cache_version == 1
    assert indexing_processor_marker.cache_version == 1

    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)
  end

  def index_record_id(id) do
    # Get record with a description.
    record = IndexingPipeline.get_figgy_resource!(id)
    # Write a current hydration marker right before that marker.
    marker = IndexingPipeline.DatabaseProducer.CacheEntryMarker.from(record)
    earlier_marker = %IndexingPipeline.DatabaseProducer.CacheEntryMarker{id: marker.id, timestamp: DateTime.add(marker.timestamp, -1, :microsecond)}
      IndexingPipeline.write_processor_marker(%{
        type: IndexingPipeline.Figgy.HydrationProducerSource.processor_marker_key(),
        cache_version: 1,
        cache_location: earlier_marker.timestamp,
        cache_record_id: earlier_marker.id
      })

    # Start the figgy producer
    {:ok, indexer} = Figgy.IndexingConsumer.start_link(cache_version: 1, batch_size: 50)
    {:ok, transformer} = Figgy.TransformationConsumer.start_link(cache_version: 1, batch_size: 50)

    # Control hydration indexing.
    {:ok, hydrator} =
      Figgy.HydrationConsumer.start_link(
        cache_version: 1,
        batch_size: 50,
        producer_module: MockFiggyHydrationProducer,
        producer_options: {self(), 1},
      )

    # Index one.
    MockFiggyHydrationProducer.process(1)
    task =
      Task.async(fn -> wait_for_indexed_count(1) end)

    Task.await(task, 15000)
    document = Solr.find_by_id(id)
    IO.inspect(Solr.document_count())
    { hydrator, transformer, indexer, document }
  end

  test "indexes description" do
    { hydrator, transformer, indexer, document } = index_record_id("26713a31-d615-49fd-adfc-93770b4f66b3")

    assert %{"description_txt" => [first_description | _tail]} = document
    assert first_description |> String.starts_with?("Asra-Panahi") == true
    IO.inspect(document)
    hydrator |> Broadway.stop(:normal)
    transformer |> Broadway.stop(:normal)
    indexer |> Broadway.stop(:normal)
  end
end
