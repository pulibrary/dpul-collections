defmodule DpulCollections.IndexingPipelineTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline

  describe "hydration_cache_entries" do
    alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry

    import DpulCollections.IndexingPipelineFixtures

    test "converting a figgy resource to a solr document" do
      # Current State
      ephemera_folder_id = "8b0631b7-e1e4-49c2-904f-cd3141167a80"
      figgy_resource = IndexingPipeline.get_figgy_resource!(ephemera_folder_id)
      # Why do we do this?
      # To save it to the database.
      # Is there a difference between a HydrationCacheEntry (thing we save to
      # the db), and the thing that gets converted from a FiggyResource and into
      # a solr document?
      hydration_cache_attrs = Figgy.Resource.to_hydration_cache_attrs(figgy_resource)
      # Turn hydration_cache_attrs into a broadway message somehow.
      hydration_cache_entry = IndexingPipeline.write_to_hydration_cache_entry(hydration_cache_attrs)
      solr_document = HydrationCacheEntry.to_solr_document(hydration_cache_entry)
      item = Item.from_solr(solr_document)

      # What would be nice - two options
      figgy_resource |> Figgy.Resource.to_hydration_cache_entry |> HydrationCacheEntry.to_solr_document |> SolrDocument.to_item
      # Differences - HydrationCacheEntry is saved to the database. To save it
      # to the database we have to pass the change set parameters, not a
      # pre-built HydrationCacheEntry.
      # Could we build the attrs necessary for persisting the
      # HydrationCacheEntry via .change_set from a built HydrationCacheEntry?
      figgy_resource |> HydrationCacheEntry.from_figgy_resource |> SolrDocument.from_hydration_cache_entry |> Item.from_solr_document
    end

    test "list_hydration_cache_entries/0 returns all hydration_cache_entries" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      assert IndexingPipeline.list_hydration_cache_entries() == [hydration_cache_entry]
    end

    test "get_hydration_cache_entry!/1 returns the hydration_cache_entry with given id" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id) ==
               hydration_cache_entry
    end

    test "delete_hydration_cache_entry/1 deletes the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert {:ok, %HydrationCacheEntry{}} =
               IndexingPipeline.delete_hydration_cache_entry(hydration_cache_entry)

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id)
      end
    end

    test "write_hydration_cache_entry/1 upserts a cache entry" do
      {:ok, first_write} =
        IndexingPipeline.write_hydration_cache_entry(%{
          data: %{},
          source_cache_order: ~U[2024-07-23 20:05:00Z],
          cache_version: 0,
          record_id: "some record_id"
        })

      {:ok, second_write} =
        IndexingPipeline.write_hydration_cache_entry(%{
          data: %{},
          source_cache_order: ~U[2024-07-24 20:05:00Z],
          cache_version: 0,
          record_id: "some record_id"
        })

      {:ok, nil} =
        IndexingPipeline.write_hydration_cache_entry(%{
          data: %{},
          source_cache_order: ~U[2024-07-22 20:05:00Z],
          cache_version: 0,
          record_id: "some record_id"
        })

      reloaded = IndexingPipeline.get_hydration_cache_entry!(second_write.id)
      assert first_write.cache_order != reloaded.cache_order
      assert reloaded.source_cache_order == second_write.source_cache_order
      assert IndexingPipeline.list_hydration_cache_entries() |> length == 1
    end
  end

  describe "processor_markers" do
    alias DpulCollections.IndexingPipeline.ProcessorMarker

    import DpulCollections.IndexingPipelineFixtures

    test "list_processor_markers/0 returns all processor_markers" do
      processor_marker = processor_marker_fixture()
      assert IndexingPipeline.list_processor_markers() == [processor_marker]
    end

    test "get_processor_marker!/1 returns the processor_marker with given id" do
      processor_marker = processor_marker_fixture()
      assert IndexingPipeline.get_processor_marker!(processor_marker.id) == processor_marker
    end

    test "delete_processor_marker/1 deletes the processor_marker" do
      processor_marker = processor_marker_fixture()

      assert {:ok, %ProcessorMarker{}} =
               IndexingPipeline.delete_processor_marker(processor_marker)

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_processor_marker!(processor_marker.id)
      end
    end
  end

  describe "figgy database" do
    alias DpulCollections.FiggyRepo
    alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker

    test "get_figgy_resource!/1 returns a resource from the figgy db" do
      ephemera_folder_id = "8b0631b7-e1e4-49c2-904f-cd3141167a80"
      assert IndexingPipeline.get_figgy_resource!(ephemera_folder_id).id == ephemera_folder_id
    end

    test "get_figgy_resource!/1 errors when the resource isn't there" do
      ephemera_folder_id = "00000000-0000-0000-0000-000000000000"

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_figgy_resource!(ephemera_folder_id)
      end
    end

    test "get_figgy_resources_since/2 doesn't return all the metadata, just a sparse record" do
      record = IndexingPipeline.get_figgy_resource!("26713a31-d615-49fd-adfc-93770b4f66b3")
      marker = IndexingPipeline.DatabaseProducer.CacheEntryMarker.from(record)

      record = IndexingPipeline.get_figgy_resources_since!(marker, 1) |> hd

      assert record.metadata == nil
      assert record.visibility == ["open"]
      assert record.state == ["complete"]
    end

    test "get_figgy_resources_since/2 pulls deleted resource IDs and types" do
      record = IndexingPipeline.get_figgy_resource!("ea2bc758-e455-493f-87fe-ecf124117fd2")
      marker = IndexingPipeline.DatabaseProducer.CacheEntryMarker.from(record)
      marker = %{marker | timestamp: marker.timestamp |> DateTime.add(-1)}

      record = IndexingPipeline.get_figgy_resources_since!(marker, 1) |> hd

      assert record.id == "ea2bc758-e455-493f-87fe-ecf124117fd2"
      assert record.metadata == nil
      assert record.metadata_resource_id == [%{"id" => "b7fc05bb-fb01-414f-a603-c5e479576674"}]
      assert record.metadata_resource_type == ["EphemeraFolder"]
    end

    test "get_figgy_resources_since!/2 does not return Events or PreservationObjects" do
      total_records = FiggyRepo.aggregate(IndexingPipeline.Figgy.Resource, :count)

      # Calling the function with a marker
      fabricated_marker = %CacheEntryMarker{
        timestamp: ~U[1018-03-09 20:19:33.414040Z],
        id: "00000000-0000-0000-0000-000000000000"
      }

      records = IndexingPipeline.get_figgy_resources_since!(fabricated_marker, total_records)

      assert records
             |> Enum.filter(fn x -> x.internal_resource == "PreservationObject" end)
             |> Enum.count() == 0

      assert records
             |> Enum.filter(fn x -> x.internal_resource == "Event" end)
             |> Enum.count() == 0

      # Call the function without marker
      records = IndexingPipeline.get_figgy_resources_since!(nil, total_records)

      assert records
             |> Enum.filter(fn x -> x.internal_resource == "PreservationObject" end)
             |> Enum.count() == 0

      assert records
             |> Enum.filter(fn x -> x.internal_resource == "Event" end)
             |> Enum.count() == 0
    end
  end

  describe "transformation_cache_entries" do
    alias DpulCollections.IndexingPipeline.Figgy

    import DpulCollections.IndexingPipelineFixtures

    test "list_transformation_cache_entries/0 returns all transformation_cache_entries" do
      transformation_cache_entry = transformation_cache_entry_fixture()

      assert IndexingPipeline.list_transformation_cache_entries() == [
               transformation_cache_entry
             ]
    end

    test "get_transformation_cache_entry!/1 returns the transformation_cache_entry with given id" do
      transformation_cache_entry = transformation_cache_entry_fixture()

      assert IndexingPipeline.get_transformation_cache_entry!(transformation_cache_entry.id) ==
               transformation_cache_entry
    end

    test "delete_transformation_cache_entry/1 deletes the transformation_cache_entry" do
      transformation_cache_entry = transformation_cache_entry_fixture()

      assert {:ok, %Figgy.TransformationCacheEntry{}} =
               IndexingPipeline.delete_transformation_cache_entry(transformation_cache_entry)

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_transformation_cache_entry!(transformation_cache_entry.id)
      end
    end

    test "delete_cache_version/1 deletes entries for that cache version from each table" do
      for cache_version <- [0, 1] do
        FiggyTestFixtures.hydration_cache_markers(cache_version)

        {marker1, _marker2, _marker3} =
          FiggyTestFixtures.transformation_cache_markers(cache_version)

        IndexingPipeline.write_processor_marker(%{
          type: IndexingPipeline.Figgy.HydrationProducerSource.processor_marker_key(),
          cache_version: cache_version,
          cache_location: marker1.timestamp,
          cache_record_id: marker1.id
        })

        IndexingPipeline.write_processor_marker(%{
          type: IndexingPipeline.Figgy.TransformationProducerSource.processor_marker_key(),
          cache_version: cache_version,
          cache_location: marker1.timestamp,
          cache_record_id: marker1.id
        })

        IndexingPipeline.write_processor_marker(%{
          type: IndexingPipeline.Figgy.IndexingProducerSource.processor_marker_key(),
          cache_version: cache_version,
          cache_location: marker1.timestamp,
          cache_record_id: marker1.id
        })
      end

      assert Enum.count(IndexingPipeline.list_hydration_cache_entries()) == 6
      assert Enum.count(IndexingPipeline.list_transformation_cache_entries()) == 6
      assert Enum.count(IndexingPipeline.list_processor_markers()) == 6

      IndexingPipeline.delete_cache_version(0)

      assert Enum.map(
               IndexingPipeline.list_hydration_cache_entries(),
               fn e -> e.cache_version end
             ) == [1, 1, 1]

      assert Enum.map(
               IndexingPipeline.list_transformation_cache_entries(),
               fn e -> e.cache_version end
             ) == [1, 1, 1]

      assert Enum.map(
               IndexingPipeline.list_processor_markers(),
               fn e -> e.cache_version end
             ) == [1, 1, 1]
    end
  end
end
