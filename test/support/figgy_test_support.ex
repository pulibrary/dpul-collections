defmodule FiggyTestSupport do
  import Ecto.Query, warn: false

  alias DpulCollections.{IndexingPipeline, Solr}
  alias DpulCollections.IndexingPipeline.Figgy

  alias DpulCollections.FiggyRepo

  def total_resource_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder" or r.internal_resource == "EphemeraTerm"

    FiggyRepo.aggregate(query, :count)
  end

  def first_ephemera_folder do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder",
        limit: 1

    FiggyRepo.one(query)
  end

  def ephemera_folder_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder"

    FiggyRepo.aggregate(query, :count)
  end

  def index_record_id(id) do
    cache_version = 1
    # Get record with a description.
    record = IndexingPipeline.get_figgy_resource!(id)
    # Write a current hydration marker right before that marker.
    marker = IndexingPipeline.DatabaseProducer.CacheEntryMarker.from(record)

    earlier_marker = %IndexingPipeline.DatabaseProducer.CacheEntryMarker{
      id: marker.id,
      timestamp: DateTime.add(marker.timestamp, -1, :microsecond)
    }

    IndexingPipeline.write_processor_marker(%{
      type: IndexingPipeline.Figgy.HydrationProducerSource.processor_marker_key(),
      cache_version: cache_version,
      cache_location: earlier_marker.timestamp,
      cache_record_id: earlier_marker.id
    })

    # Start the figgy producer
    {:ok, indexer} =
      Figgy.IndexingConsumer.start_link(
        cache_version: cache_version,
        batch_size: 50,
        write_collection: SolrTestSupport.active_collection()
      )

    {:ok, transformer} =
      Figgy.TransformationConsumer.start_link(cache_version: cache_version, batch_size: 50)

    # Control hydration indexing.
    {:ok, hydrator} =
      Figgy.HydrationConsumer.start_link(
        cache_version: cache_version,
        batch_size: 50,
        producer_module: MockFiggyHydrationProducer,
        producer_options: {self(), 1}
      )

    # Index one.
    MockFiggyHydrationProducer.process(1, cache_version)

    task =
      Task.async(fn -> wait_for_indexed_count(1) end)

    Task.await(task, 15000)
    document = Solr.find_by_id(id)
    {hydrator, transformer, indexer, document}
  end

  def wait_for_indexed_count(count) do
    collection = Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
    DpulCollections.Solr.commit(collection)

    continue =
      if DpulCollections.Solr.document_count() == count do
        true
      else
        false
      end

    continue || (:timer.sleep(100) && wait_for_indexed_count(count))
  end
end
