defmodule DpulCollections.IndexingPipelineTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline

  describe "hydration_cache_entries" do
    alias DpulCollections.IndexingPipeline.HydrationCacheEntry

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
end
