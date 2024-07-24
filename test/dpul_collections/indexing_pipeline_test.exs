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
      assert IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id) == hydration_cache_entry
    end

    test "create_hydration_cache_entry/1 with valid data creates a hydration_cache_entry" do
      valid_attrs = %{data: "some data", cache_version: 42, record_id: "some record_id", source_cache_order: ~U[2024-07-23 20:05:00Z]}

      assert {:ok, %HydrationCacheEntry{} = hydration_cache_entry} = IndexingPipeline.create_hydration_cache_entry(valid_attrs)
      assert hydration_cache_entry.data == "some data"
      assert hydration_cache_entry.cache_version == 42
      assert hydration_cache_entry.record_id == "some record_id"
      assert hydration_cache_entry.source_cache_order == ~U[2024-07-23 20:05:00Z]
    end

    test "create_hydration_cache_entry/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = IndexingPipeline.create_hydration_cache_entry(@invalid_attrs)
    end

    test "update_hydration_cache_entry/2 with valid data updates the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      update_attrs = %{data: "some updated data", cache_version: 43, record_id: "some updated record_id", source_cache_order: ~U[2024-07-24 20:05:00Z]}

      assert {:ok, %HydrationCacheEntry{} = hydration_cache_entry} = IndexingPipeline.update_hydration_cache_entry(hydration_cache_entry, update_attrs)
      assert hydration_cache_entry.data == "some updated data"
      assert hydration_cache_entry.cache_version == 43
      assert hydration_cache_entry.record_id == "some updated record_id"
      assert hydration_cache_entry.source_cache_order == ~U[2024-07-24 20:05:00Z]
    end

    test "update_hydration_cache_entry/2 with invalid data returns error changeset" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      assert {:error, %Ecto.Changeset{}} = IndexingPipeline.update_hydration_cache_entry(hydration_cache_entry, @invalid_attrs)
      assert hydration_cache_entry == IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id)
    end

    test "delete_hydration_cache_entry/1 deletes the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      assert {:ok, %HydrationCacheEntry{}} = IndexingPipeline.delete_hydration_cache_entry(hydration_cache_entry)
      assert_raise Ecto.NoResultsError, fn -> IndexingPipeline.get_hydration_cache_entry!(hydration_cache_entry.id) end
    end

    test "change_hydration_cache_entry/1 returns a hydration_cache_entry changeset" do
      hydration_cache_entry = hydration_cache_entry_fixture()
      assert %Ecto.Changeset{} = IndexingPipeline.change_hydration_cache_entry(hydration_cache_entry)
    end
  end
end
