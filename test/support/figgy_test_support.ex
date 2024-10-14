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

  def ephemera_folder_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder"

    FiggyRepo.aggregate(query, :count)
  end

  def index_record_id(id) do
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
        producer_options: {self(), 1}
      )

    # Index one.
    MockFiggyHydrationProducer.process(1)

    task =
      Task.async(fn -> wait_for_indexed_count(1) end)

    Task.await(task, 15000)
    document = Solr.find_by_id(id)
    {hydrator, transformer, indexer, document}
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
end
