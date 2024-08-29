defmodule DpulCollections.IndexingPipelineTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline

  describe "hydration_cache_entries" do
    alias DpulCollections.IndexingPipeline.HydrationCacheEntry

    import DpulCollections.IndexingPipelineFixtures

    @invalid_attrs %{data: nil, cache_version: nil, record_id: nil, source_cache_order: nil}

    test "list_hydration_cache_entries/0 returns all hydration_cache_entries" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      assert IndexingPipeline.list_hydration_cache_entries() == [hydration_cache_entry]
    end

    test "get_hydration_cache_entry!/1 returns the hydration_cache_entry with given id" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id) ==
               hydration_cache_entry
    end

    test "update_hydration_cache_entry/2 with valid data updates the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      update_attrs = %{
        data: %{},
        cache_version: 43,
        record_id: "some updated record_id",
        source_cache_order: ~U[2024-07-24 20:05:00Z]
      }

      assert {:ok, %HydrationCacheEntry{} = hydration_cache_entry} =
               IndexingPipeline.update_hydration_cache_entry(hydration_cache_entry, update_attrs)

      assert hydration_cache_entry.data == %{}
      assert hydration_cache_entry.cache_version == 43
      assert hydration_cache_entry.record_id == "some updated record_id"
      assert hydration_cache_entry.source_cache_order == ~U[2024-07-24 20:05:00.000000Z]
    end

    test "update_hydration_cache_entry/2 with invalid data returns error changeset" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert {:error, %Ecto.Changeset{}} =
               IndexingPipeline.update_hydration_cache_entry(
                 hydration_cache_entry,
                 @invalid_attrs
               )

      assert hydration_cache_entry ==
               IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id)
    end

    test "delete_hydration_cache_entry/1 deletes the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert {:ok, %HydrationCacheEntry{}} =
               IndexingPipeline.delete_hydration_cache_entry(hydration_cache_entry)

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id)
      end
    end

    test "change_hydration_cache_entry/1 returns a hydration_cache_entry changeset" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      assert %Ecto.Changeset{} =
               IndexingPipeline.change_hydration_cache_entry(hydration_cache_entry)
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
