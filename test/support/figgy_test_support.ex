defmodule FiggyTestSupport do
  import Ecto.Query, warn: false

  alias DpulCollections.{IndexingPipeline, Solr}
  alias DpulCollections.IndexingPipeline.Figgy

  alias DpulCollections.FiggyRepo

  def total_resource_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "EphemeraFolder" or r.internal_resource == "DeletionMarker"

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

  def deletion_marker_count do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "DeletionMarker"

    FiggyRepo.aggregate(query, :count)
  end

  def deletion_markers do
    query =
      from r in Figgy.Resource,
        where: r.internal_resource == "DeletionMarker"

    FiggyRepo.all(query)
  end

  def index_record(record, cache_version \\ 1) do
    # Write a current hydration marker right before that marker.
    marker = IndexingPipeline.DatabaseProducer.CacheEntryMarker.from(record)
    cache_attrs = Figgy.Resource.to_hydration_cache_attrs(record)

    {:ok, cache_entry} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: marker.id,
        related_ids: cache_attrs.related_ids,
        source_cache_order: marker.timestamp,
        source_cache_order_record_id: marker.id,
        data: cache_attrs.handled_data
      })

    hydration_cache_entry =
      IndexingPipeline.get_hydration_cache_entry!(cache_entry.id)
      # Add a member_id so to_solr_document won't return a deletion marker and
      # can index - but we don't want that in the hydration cache entry, because
      # that makes hydration cache entries where a bunch of records have the
      # same file set.
      |> put_in([Access.key(:data), Access.key("metadata")], record.metadata)
      |> put_in([Access.key(:data), Access.key("metadata"), Access.key("member_ids")], [
        %{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}
      ])

    solr_doc = Figgy.HydrationCacheEntry.to_solr_document(hydration_cache_entry)

    IndexingPipeline.write_transformation_cache_entry(%{
      cache_version: cache_version,
      record_id: hydration_cache_entry |> Map.get(:record_id),
      source_cache_order: hydration_cache_entry |> Map.get(:cache_order),
      data: solr_doc
    })

    Solr.add(solr_doc)
    Solr.commit()

    solr_doc
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
        solr_index: SolrTestSupport.active_collection()
      )

    {:ok, tracker_pid} = GenServer.start_link(AckTracker, self())

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

    AckTracker.wait_for_indexed_count(1)

    document = Solr.find_by_id(id)
    {hydrator, transformer, indexer, document}
  end

  def wait_for_indexed_count(count) do
    index = Solr.Index.read_index()
    DpulCollections.Solr.commit(index)

    continue =
      if DpulCollections.Solr.document_count() == count do
        true
      else
        false
      end

    continue || (:timer.sleep(100) && wait_for_indexed_count(count))
  end
end
