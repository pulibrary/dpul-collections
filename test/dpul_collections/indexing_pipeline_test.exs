defmodule DpulCollections.IndexingPipelineTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline

  describe "hydration_cache_entries" do
    alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry

    import DpulCollections.IndexingPipelineFixtures

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
    test "get_figgy_resource!/1 returns a resource from the figgy db" do
      ephemera_folder_id = "8b0631b7-e1e4-49c2-904f-cd3141167a80"
      assert IndexingPipeline.get_figgy_resource!(ephemera_folder_id).id == ephemera_folder_id
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
  end
end
