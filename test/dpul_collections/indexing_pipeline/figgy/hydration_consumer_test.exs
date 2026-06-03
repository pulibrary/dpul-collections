defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumerTest do
  use DpulCollections.DataCase
  import Mock

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.HydrationConsumer

  describe "Figgy.HydrationConsumer" do
    test "process_and_persist/2 does nothing for ephemera terms that don't have any related IDs" do
      # This is "Washo", which we don't have anything labeled with in our test
      # set.
      ephemera_term = IndexingPipeline.get_figgy_resource!("1ebf9915-d865-4dc0-8f6f-56e19ce07248")
      Figgy.HydrationConsumer.process_and_persist(ephemera_term, 1)
      assert IndexingPipeline.list_hydration_cache_entries() == []
    end

    test "process_and_persist/2 when a message is not a complete and visible EphemeraFolder, it is not saved" do
      # First save an ephemera folder that creates a hydration cache entry.
      ephemera_folder = %Figgy.Resource{
        id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "title" => ["title"],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
        }
      }

      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      # There's only one, and it's the ephemera folder.
      assert [ephemera_folder_cache_entry] = IndexingPipeline.list_hydration_cache_entries()
      assert ephemera_folder_cache_entry.data["metadata"]["title"] == ["title"]

      # Mark the above ephemera folder pending - this should mark it deleted.
      pending_ephemera_folder =
        %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "title" => ["title"],
            "state" => ["pending"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }

      Figgy.HydrationConsumer.process_and_persist(pending_ephemera_folder, 1)
      assert [ephemera_folder_cache_entry] = IndexingPipeline.list_hydration_cache_entries()
      assert ephemera_folder_cache_entry.data["metadata"]["deleted"] == true

      # Mark the above restricted. Continues to be marked deleted, but it's
      # updated with the new timestamp.
      restricted_ephemera_folder =
        %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:29:57.526110Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "title" => ["title"],
            "state" => ["complete"],
            "visibility" => ["restricted"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }

      Figgy.HydrationConsumer.process_and_persist(restricted_ephemera_folder, 1)

      assert [restricted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      assert restricted_ephemera_folder_cache_entry.data["metadata"]["deleted"] == true

      assert restricted_ephemera_folder_cache_entry.source_cache_order !=
               ephemera_folder_cache_entry.source_cache_order

      # Ephemera Terms don't create cache entries.
      ephemera_term =
        %Figgy.Resource{
          id: "3cb7627b-defc-401b-9959-42ebc4488f74",
          updated_at: ~U[2018-03-09 20:19:33.414040Z],
          internal_resource: "EphemeraTerm"
        }

      Figgy.HydrationConsumer.process_and_persist(ephemera_term, 1)

      assert [^restricted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      # Basic scanned resources get skipped, no new entries.
      scanned_resource =
        %Figgy.Resource{
          id: "2fa1b92b-9e62-4694-aeab-0c4fab72ac24",
          updated_at: ~U[2025-08-18 20:19:34.465203Z],
          internal_resource: "ScannedResource",
          metadata: %{}
        }

      Figgy.HydrationConsumer.process_and_persist(scanned_resource, 1)

      assert [^restricted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      # Deletion Markers for things without hydration cache entries get skipped.
      file_set_deletion_marker =
        %Figgy.Resource{
          id: "9773417d-1c36-4692-bf81-f387be688460",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata: %{
            "resource_id" => [%{"id" => "a521113e-e77a-4000-b00a-17c09b3aa757"}],
            "resource_type" => ["FileSet"]
          }
        }

      Figgy.HydrationConsumer.process_and_persist(file_set_deletion_marker, 1)

      assert [^restricted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()
    end

    test "process_and_perist/2 only processes deletion markers with related resources in the HydrationCache" do
      ephemera_folder =
        %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "title" => ["title"],
            "visibility" => ["open"],
            "state" => ["complete"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }

      # DeletionMarker that corresponds to a resource with a hydration cache entry
      ephemera_folder_deletion_marker =
        %Figgy.Resource{
          id: "dced9109-6980-4035-9764-84c08ed5d7db",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "561ea64a-9cd1-4994-b2a7-ac169f33ba84"}],
          metadata_resource_type: ["EphemeraFolder"]
        }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker1 =
        %Figgy.Resource{
          id: "f8f62bdf-9d7b-438f-9870-1793358e5fe1",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "fc8d345b-6e87-461e-9182-41eaede1fab6"}],
          metadata_resource_type: ["EphemeraFolder"]
        }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker2 =
        %Figgy.Resource{
          id: "1a2e9bef-e50d-4a9c-81f1-8d8e82f3a8e4",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "e0d4e6f6-29f2-4fd7-9c8a-7293ae0d7689"}],
          metadata_resource_type: ["EphemeraFolder"]
        }

      # Create a cache entry for the ephemera folder.
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      assert [ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      # Process the deletion marker - this will update the record and delete it.
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder_deletion_marker, 1)

      assert [deleted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      assert ephemera_folder_cache_entry.record_id ==
               deleted_ephemera_folder_cache_entry.record_id

      # It's marked to be deleted.
      assert deleted_ephemera_folder_cache_entry.data["metadata"]["deleted"] == true

      # Processing deletion markers after it's gone will do nothing.
      Figgy.HydrationConsumer.process_and_persist(orphaned_deletion_marker1, 1)
      Figgy.HydrationConsumer.process_and_persist(orphaned_deletion_marker2, 1)

      assert [reloaded_deleted_ephemera_folder_cache_entry] =
               IndexingPipeline.list_hydration_cache_entries()

      assert reloaded_deleted_ephemera_folder_cache_entry.cache_order ==
               deleted_ephemera_folder_cache_entry.cache_order
    end

    test "process_and_persist/2 skips ScannedResources whose member_of_collection_ids is nil" do
      scanned_resource = %Figgy.Resource{
        id: "2fa1b92b-9e62-4694-aeab-0c4fab72ac24",
        updated_at: ~U[2025-08-18 20:19:34.465203Z],
        internal_resource: "ScannedResource",
        metadata: %{
          "title" => ["title"],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_of_collection_ids" => nil
        }
      }

      Figgy.HydrationConsumer.process_and_persist(scanned_resource, 1)
      assert IndexingPipeline.list_hydration_cache_entries() == []
    end

    test "process_and_persist/2 deletes EphemeraFolders when their state or visibility change" do
      ephemera_folder_1 = %Figgy.Resource{
        id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
        updated_at: ~U[2025-04-18 14:28:57.52611Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
        }
      }

      ephemera_folder_2 = %Figgy.Resource{
        id: "31732974-611e-4c06-8af3-928e553b6c9f",
        updated_at: ~U[2025-04-18 14:29:09.201335Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "ee769854-2d5f-4d79-81d9-3fdbb27fa168"}]
        }
      }

      updated_visibility_ephemera_folder = %Figgy.Resource{
        id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
        updated_at: ~U[2025-04-19 14:28:57.52611Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["restricted"],
          "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
        }
      }

      updated_state_ephemera_folder = %Figgy.Resource{
        id: "31732974-611e-4c06-8af3-928e553b6c9f",
        updated_at: ~U[2025-04-19 14:29:09.201335Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["pending"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "ee769854-2d5f-4d79-81d9-3fdbb27fa168"}]
        }
      }

      # Create hydration cache entries
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder_1, 1)
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder_2, 1)

      # Process updated ephemera folders
      Figgy.HydrationConsumer.process_and_persist(updated_visibility_ephemera_folder, 1)
      Figgy.HydrationConsumer.process_and_persist(updated_state_ephemera_folder, 1)

      # A transformed hydration cache entry is created which replaces an
      # existing ephemera folder's hydration cache entry. It's metadata field
      # only has the value `deleted` set to true. This signals the
      # transformation consumer to create a transformation cache entry with a
      # solr record that indicates it should be deleted from the index.
      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 2

      sorted_entries = Enum.sort(hydration_cache_entries, &(&1.record_id >= &2.record_id))

      hydration_cache_entry = sorted_entries |> Enum.at(0)
      assert hydration_cache_entry.data["internal_resource"] == "EphemeraFolder"
      assert hydration_cache_entry.record_id == ephemera_folder_2.id
      assert hydration_cache_entry.data["id"] == ephemera_folder_2.id
      assert hydration_cache_entry.data["metadata"]["deleted"] == true

      hydration_cache_entry = sorted_entries |> Enum.at(1)
      assert hydration_cache_entry.data["internal_resource"] == "EphemeraFolder"
      assert hydration_cache_entry.record_id == ephemera_folder_1.id
      assert hydration_cache_entry.data["id"] == ephemera_folder_1.id
      assert hydration_cache_entry.data["metadata"]["deleted"] == true
    end

    test "process_and_persist/2 updates an EphemeraFolder when a related EphemeraTerm changes" do
      ephemera_folder = %Figgy.Resource{
        id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}],
          "genre" => [%{"id" => "01e15ce8-1a11-4342-b7b5-82cbff248b4d"}]
        }
      }

      updated_ephemera_term_resource = %Figgy.Resource{
        id: "01e15ce8-1a11-4342-b7b5-82cbff248b4d",
        updated_at: ~U[2025-07-09 20:19:35.340016Z],
        internal_resource: "EphemeraTerm",
        metadata: %{
          "label" => ["UpdatedTerm"]
        }
      }

      file_set = IndexingPipeline.get_figgy_resource!("c42bca4b-02c9-44ad-b6bd-132ab27a8986")

      # Create a hydration cache entry
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder.id

      # Check un-updated term label
      related_resource_entry =
        hydration_cache_entry.related_data["resources"][updated_ephemera_term_resource.id]

      assert related_resource_entry["metadata"]["label"] == ["Organic farming"]

      # Mock IndexingPipeline.get_figgy_resources function so:
      #   1. query for EphemeraFolder is passed through to the database
      #   2. empty query is passed through
      #   3. other queries only return the updated EphemeraTerm
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          ["05092b7d-d33c-4d4d-885e-b6b8973deec4"] ->
            passthrough([["05092b7d-d33c-4d4d-885e-b6b8973deec4"]])

          [] ->
            passthrough([[]])

          _ ->
            [updated_ephemera_term_resource, file_set]
        end do
        # Process updated ephemera term
        Figgy.HydrationConsumer.process_and_persist(updated_ephemera_term_resource, 1)

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_term_resource.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_term_resource.id

        # Check updated term label
        related_resource_entry =
          hydration_cache_entry.related_data["resources"][updated_ephemera_term_resource.id]

        assert related_resource_entry["metadata"]["label"] == ["UpdatedTerm"]
      end
    end

    test "process_and_persist/2 does not update an EphemeraFolder when a related resources changes but has an older timestamp" do
      ephemera_folder = %Figgy.Resource{
        id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}],
          "genre" => [%{"id" => "01e15ce8-1a11-4342-b7b5-82cbff248b4d"}]
        }
      }

      updated_ephemera_term_resource = %Figgy.Resource{
        id: "01e15ce8-1a11-4342-b7b5-82cbff248b4d",
        updated_at: ~U[2023-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraTerm",
        metadata: %{
          "label" => ["UpdatedTerm"]
        }
      }

      # Create a hydration cache entry
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      # Mock IndexingPipeline.get_figgy_resources function so:
      #   1. query for EphemeraFolder is passed through to the database
      #   2. empty query is passed through
      #   3. other queries only return the updated EphemeraTerm
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          ["05092b7d-d33c-4d4d-885e-b6b8973deec4"] ->
            passthrough([["05092b7d-d33c-4d4d-885e-b6b8973deec4"]])

          [] ->
            passthrough([[]])

          _ ->
            [updated_ephemera_term_resource]
        end do
        # Process updated ephemera term
        Figgy.HydrationConsumer.process_and_persist(updated_ephemera_term_resource, 1)

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder.id

        # Test that the ephemera folder was not updated
        assert hydration_cache_entry.source_cache_order !=
                 updated_ephemera_term_resource.updated_at

        assert hydration_cache_entry.source_cache_order_record_id !=
                 updated_ephemera_term_resource.id
      end
    end

    test "process_and_persist/2 updates an EphemeraFolder when a related FileSet changes" do
      ephemera_folder = %Figgy.Resource{
        id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
        }
      }

      updated_file_set_resource = %Figgy.Resource{
        id: "c42bca4b-02c9-44ad-b6bd-132ab27a8986",
        updated_at: ~U[2025-07-09 20:19:35.340016Z],
        internal_resource: "FileSet",
        metadata: %{
          "file_metadata" => [
            %{
              "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4017"},
              "internal_resource" => "FileMetadata",
              "mime_type" => ["image/tiff"],
              "height" => ["10937"],
              "width" => ["7286"],
              "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
            },
            %{
              "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab1111"},
              "internal_resource" => "FileMetadata",
              "mime_type" => ["image/tiff"],
              "height" => ["10937"],
              "width" => ["7286"],
              "use" => [%{"@id" => "http://pcdm.org/use#OriginalFile"}]
            }
          ]
        }
      }

      # Create a hydration cache entry
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      # Mock IndexingPipeline.get_figgy_resources function so:
      #   1. query for EphemeraFolder is passed through to the database
      #   2. empty query is passed through
      #   3. other queries only return the updated file set resource
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          ["05092b7d-d33c-4d4d-885e-b6b8973deec4"] ->
            passthrough([["05092b7d-d33c-4d4d-885e-b6b8973deec4"]])

          [] ->
            passthrough([[]])

          _ ->
            [updated_file_set_resource]
        end do
        # Process updated file set
        Figgy.HydrationConsumer.process_and_persist(updated_file_set_resource, 1)

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_file_set_resource.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_file_set_resource.id
      end
    end

    test "process_and_persist/2 updates an EphemeraFolder when a parent EphemeraBox changes" do
      ephemera_folder = %Figgy.Resource{
        id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}],
          "title" => ["Folder"]
        }
      }

      updated_ephemera_box_resource = %Figgy.Resource{
        id: "82624edb-c360-4d8a-b202-f103ee639e8e",
        internal_resource: "EphemeraBox",
        updated_at: ~U[2030-07-09 20:19:35.340016Z],
        created_at: ~U[2030-07-09 20:19:35.340016Z],
        metadata: %{
          "box_number" => ["different_box"],
          "cached_parent_id" => [%{"id" => "2961c153-54ab-4c6a-b5cd-aa992f4c349b"}],
          "member_ids" => [
            %{"id" => "561ea64a-9cd1-4994-b2a7-ac169f33ba84"}
          ]
        }
      }

      # Create a hydration cache entry
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder.id

      # Check un-updated box number
      related_resource_entry =
        hydration_cache_entry.related_data["ancestors"][updated_ephemera_box_resource.id]

      assert related_resource_entry["metadata"]["box_number"] == [
               "Woman Life Freedom Movement: Iran 2022"
             ]

      # Mock IndexingPipeline.get_figgy_parents function so:
      #   1. query for EphemeraFolder parent returns updated_ephemera_box
      #   2. other queriea are passed through
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_parents: fn
          "561ea64a-9cd1-4994-b2a7-ac169f33ba84" -> [updated_ephemera_box_resource]
          id -> passthrough([id])
        end do
        # Process updated ephemera box
        Figgy.HydrationConsumer.process_and_persist(updated_ephemera_box_resource, 1)

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_box_resource.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_box_resource.id

        # Check updated box number
        related_resource_entry =
          hydration_cache_entry.related_data["ancestors"][updated_ephemera_box_resource.id]

        assert related_resource_entry["metadata"]["box_number"] == ["different_box"]
      end
    end

    test "process_and_persist/2 updates an EphemeraFolder when a grandparent EphemeraProject changes" do
      ephemera_folder = %Figgy.Resource{
        id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
        updated_at: ~U[2024-04-18 14:28:57.526110Z],
        internal_resource: "EphemeraFolder",
        metadata: %{
          "cached_parent_id" => [%{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}],
          "state" => ["complete"],
          "visibility" => ["open"],
          "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}],
          "title" => ["Folder"]
        }
      }

      updated_ephemera_project_resource = %Figgy.Resource{
        id: "2961c153-54ab-4c6a-b5cd-aa992f4c349b",
        internal_resource: "EphemeraProject",
        updated_at: ~U[2030-07-09 20:19:35.340016Z],
        created_at: ~U[2030-07-09 20:19:35.340016Z],
        metadata: %{
          "member_ids" => [
            %{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}
          ],
          "title" => ["Updated EphemeraProject Title"]
        }
      }

      # Create a hydration cache entry
      Figgy.HydrationConsumer.process_and_persist(ephemera_folder, 1)

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder.id

      # Check un-updated project title
      related_resource_entry =
        hydration_cache_entry.related_data["ancestors"][updated_ephemera_project_resource.id]

      assert related_resource_entry["metadata"]["title"] == [
               "Woman Life Freedom Movement: Iran 2022"
             ]

      # Mock IndexingPipeline.get_figgy_parents function so:
      #   1. query for EphemeraBox parent returns updated_ephemera_project
      #   2. other queriea are passed through
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_parents: fn
          "82624edb-c360-4d8a-b202-f103ee639e8e" -> [updated_ephemera_project_resource]
          id -> passthrough([id])
        end do
        # Process updated ephemera project
        Figgy.HydrationConsumer.process_and_persist(updated_ephemera_project_resource, 1)

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_project_resource.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_project_resource.id

        # Check updated project title
        related_resource_entry =
          hydration_cache_entry.related_data["ancestors"][updated_ephemera_project_resource.id]

        assert related_resource_entry["metadata"]["title"] == ["Updated EphemeraProject Title"]
      end
    end
  end

  describe "Collection processing" do
    test "skips collections that are unpublished" do
      # princetoncollectors collection
      collection = IndexingPipeline.get_figgy_resource!("62339f65-ce6d-4c85-ab77-67c70abb8709")

      HydrationConsumer.process_and_persist(collection, 1)
      assert IndexingPipeline.list_hydration_cache_entries() == []
    end

    test "deletes collections that were once published" do
      collection = IndexingPipeline.get_figgy_resource!("52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a")

      HydrationConsumer.process_and_persist(collection, 1)

      unpublished_collection = put_in(collection, [Access.key!(:metadata), "publish"], ["0"])

      HydrationConsumer.process_and_persist(unpublished_collection, 1)

      cache_entry = DpulCollections.IndexingPipeline.get_hydration_cache_entry!(collection.id, 1)
      assert cache_entry.data["metadata"]["deleted"] == true
    end

    test "updates collections that are published" do
      collection = IndexingPipeline.get_figgy_resource!("52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a")

      HydrationConsumer.process_and_persist(collection, 1)

      cache_entry = DpulCollections.IndexingPipeline.get_hydration_cache_entry!(collection.id, 1)

      # No related data
      assert cache_entry.related_data["resources"] == nil
      assert cache_entry.related_ids == []
    end

    test "updates related items when it changes" do
      collection = IndexingPipeline.get_figgy_resource!("52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a")
      item = IndexingPipeline.get_figgy_resource!("159ba3f9-feab-49dd-bc71-ca08995006d9")

      HydrationConsumer.process_and_persist(collection, 1)
      HydrationConsumer.process_and_persist(item, 1)

      new_title_collection =
        collection
        |> put_in([Access.key!(:metadata), "title"], ["Test Title"])
        |> put_in([Access.key!(:updated_at)], DateTime.utc_now())

      # Mock IndexingPipeline.get_figgy_resources function so:
      #   1. query for Collection returns the updated collection
      #   2. everything else passes through
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          # These are all the collections this item is a member of.
          [
            "3b230de6-e7d3-4482-8f19-d76c8491cec3",
            "3bab572e-6603-4abf-8305-16ce6fe3ac5c",
            "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
            "62339f65-ce6d-4c85-ab77-67c70abb8709"
          ] ->
            [new_title_collection]

          ids ->
            passthrough([ids])
        end do
        HydrationConsumer.process_and_persist(new_title_collection, 1)
      end

      collection_cache_entry =
        DpulCollections.IndexingPipeline.get_hydration_cache_entry!(collection.id, 1)

      cache_entry = DpulCollections.IndexingPipeline.get_hydration_cache_entry!(item.id, 1)

      assert collection_cache_entry.data["metadata"]["title"] == ["Test Title"]
      assert Enum.find_index(cache_entry.related_ids, fn x -> x == collection.id end) != nil

      assert cache_entry.related_data["ancestors"][collection.id]["metadata"]["title"] == [
               "Test Title"
             ]
    end
  end

  describe "EphemeraProject processing" do
    test "skips projects that are unpublished" do
      project = IndexingPipeline.get_figgy_resource!("f09fc91d-7a9b-47b5-afff-ce7db76b4e92")

      HydrationConsumer.process_and_persist(project, 1)
      assert IndexingPipeline.list_hydration_cache_entries() == []
    end

    test "deletes projects that were once published" do
      project = IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")

      HydrationConsumer.process_and_persist(project, 1)

      unpublished_project = put_in(project, [Access.key!(:metadata), "publish"], ["0"])

      HydrationConsumer.process_and_persist(unpublished_project, 1)

      cache_entry = DpulCollections.IndexingPipeline.get_hydration_cache_entry!(project.id, 1)
      assert cache_entry.data["metadata"]["deleted"] == true
    end

    test "updates projects that are published" do
      project = IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")

      HydrationConsumer.process_and_persist(project, 1)

      cache_entry = DpulCollections.IndexingPipeline.get_hydration_cache_entry!(project.id, 1)

      # No related data
      assert cache_entry.related_data["resources"] == %{}
      assert cache_entry.related_ids == []
    end
  end
end
