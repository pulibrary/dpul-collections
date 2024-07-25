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

    test "create_hydration_cache_entry/1 with valid data creates a hydration_cache_entry" do
      valid_attrs = %{
        data: "some data",
        cache_version: 42,
        record_id: "some record_id",
        source_cache_order: ~U[2024-07-23 20:05:00Z]
      }

      assert {:ok, %HydrationCacheEntry{} = hydration_cache_entry} =
               IndexingPipeline.create_hydration_cache_entry(valid_attrs)

      assert hydration_cache_entry.data == "some data"
      assert hydration_cache_entry.cache_version == 42
      assert hydration_cache_entry.record_id == "some record_id"
      assert hydration_cache_entry.source_cache_order == ~U[2024-07-23 20:05:00Z]
    end

    test "create_hydration_cache_entry/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               IndexingPipeline.create_hydration_cache_entry(@invalid_attrs)
    end

    test "update_hydration_cache_entry/2 with valid data updates the hydration_cache_entry" do
      hydration_cache_entry = hydration_cache_entry_fixture()

      update_attrs = %{
        data: "some updated data",
        cache_version: 43,
        record_id: "some updated record_id",
        source_cache_order: ~U[2024-07-24 20:05:00Z]
      }

      assert {:ok, %HydrationCacheEntry{} = hydration_cache_entry} =
               IndexingPipeline.update_hydration_cache_entry(hydration_cache_entry, update_attrs)

      assert hydration_cache_entry.data == "some updated data"
      assert hydration_cache_entry.cache_version == 43
      assert hydration_cache_entry.record_id == "some updated record_id"
      assert hydration_cache_entry.source_cache_order == ~U[2024-07-24 20:05:00Z]
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

    @invalid_attrs %{type: nil, cache_location: nil, cache_version: nil}

    test "list_processor_markers/0 returns all processor_markers" do
      processor_marker = processor_marker_fixture()
      assert IndexingPipeline.list_processor_markers() == [processor_marker]
    end

    test "get_processor_marker!/1 returns the processor_marker with given id" do
      processor_marker = processor_marker_fixture()
      assert IndexingPipeline.get_processor_marker!(processor_marker.id) == processor_marker
    end

    test "create_processor_marker/1 with valid data creates a processor_marker" do
      valid_attrs = %{
        type: "some type",
        cache_location: ~U[2024-07-23 20:40:00Z],
        cache_version: 42
      }

      assert {:ok, %ProcessorMarker{} = processor_marker} =
               IndexingPipeline.create_processor_marker(valid_attrs)

      assert processor_marker.type == "some type"
      assert processor_marker.cache_location == ~U[2024-07-23 20:40:00Z]
      assert processor_marker.cache_version == 42
    end

    test "create_processor_marker/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               IndexingPipeline.create_processor_marker(@invalid_attrs)
    end

    test "update_processor_marker/2 with valid data updates the processor_marker" do
      processor_marker = processor_marker_fixture()

      update_attrs = %{
        type: "some updated type",
        cache_location: ~U[2024-07-24 20:40:00Z],
        cache_version: 43
      }

      assert {:ok, %ProcessorMarker{} = processor_marker} =
               IndexingPipeline.update_processor_marker(processor_marker, update_attrs)

      assert processor_marker.type == "some updated type"
      assert processor_marker.cache_location == ~U[2024-07-24 20:40:00Z]
      assert processor_marker.cache_version == 43
    end

    test "update_processor_marker/2 with invalid data returns error changeset" do
      processor_marker = processor_marker_fixture()

      assert {:error, %Ecto.Changeset{}} =
               IndexingPipeline.update_processor_marker(processor_marker, @invalid_attrs)

      assert processor_marker == IndexingPipeline.get_processor_marker!(processor_marker.id)
    end

    test "delete_processor_marker/1 deletes the processor_marker" do
      processor_marker = processor_marker_fixture()

      assert {:ok, %ProcessorMarker{}} =
               IndexingPipeline.delete_processor_marker(processor_marker)

      assert_raise Ecto.NoResultsError, fn ->
        IndexingPipeline.get_processor_marker!(processor_marker.id)
      end
    end

    test "change_processor_marker/1 returns a processor_marker changeset" do
      processor_marker = processor_marker_fixture()
      assert %Ecto.Changeset{} = IndexingPipeline.change_processor_marker(processor_marker)
    end
  end

  describe "figgy database" do
    test "get_figgy_resource!/1 returns a resource from the figgy db" do
      assert IndexingPipeline.get_figgy_resource!("8b0631b7-e1e4-49c2-904f-cd3141167a80").id == "8b0631b7-e1e4-49c2-904f-cd3141167a80"
    end
  end
end
