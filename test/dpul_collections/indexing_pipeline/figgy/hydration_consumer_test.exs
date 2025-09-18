defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumerTest do
  use DpulCollections.DataCase
  import Mock

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.{Resource, HydrationConsumer}

  describe "Figgy.HydrationConsumer" do
    test "process/1 returns a skip for ephemera terms that don't have any related IDs" do
      # This is "Washo", which we don't have anything labeled with in our test
      # set.
      ephemera_term = IndexingPipeline.get_figgy_resource!("1ebf9915-d865-4dc0-8f6f-56e19ce07248")
      assert {:skip, _} = Figgy.HydrationConsumer.process(ephemera_term, 1)
    end

    test "handle_message/3 when a message is not a complete and visible EphemeraFolder, it is sent to noop batcher" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }
      }

      pending_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["pending"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "state" => ["pending"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }
      }

      restricted_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["restricted"],
          metadata: %{
            "title" => ["title"],
            "state" => ["complete"],
            "visibility" => ["restricted"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }
      }

      ephemera_term_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "3cb7627b-defc-401b-9959-42ebc4488f74",
          updated_at: ~U[2018-03-09 20:19:33.414040Z],
          internal_resource: "EphemeraTerm"
        }
      }

      scanned_resource_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "2fa1b92b-9e62-4694-aeab-0c4fab72ac24",
          updated_at: ~U[2025-08-18 20:19:34.465203Z],
          internal_resource: "ScannedResource"
        }
      }

      file_set_deletion_marker_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "9773417d-1c36-4692-bf81-f387be688460",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "a521113e-e77a-4000-b00a-17c09b3aa757"}],
          metadata_resource_type: ["FileSet"]
        }
      }

      transformed_messages =
        [
          ephemera_folder_message,
          pending_ephemera_folder_message,
          restricted_ephemera_folder_message,
          ephemera_term_message,
          scanned_resource_message,
          file_set_deletion_marker_message
        ]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      message_batchers =
        transformed_messages
        |> Enum.map(&Map.get(&1, :batcher))

      assert message_batchers == [:default, :noop, :noop, :noop, :noop, :noop]
    end

    test "handle_batch/3 only processes deletion markers with related resources in the HydrationCache" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "visibility" => ["open"],
            "state" => ["complete"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}]
          }
        }
      }

      # DeletionMarker that corresponds to a resource with a hydration cache entry
      ephemera_folder_deletion_marker_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "dced9109-6980-4035-9764-84c08ed5d7db",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "561ea64a-9cd1-4994-b2a7-ac169f33ba84"}],
          metadata_resource_type: ["EphemeraFolder"]
        }
      }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker_message1 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "f8f62bdf-9d7b-438f-9870-1793358e5fe1",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "fc8d345b-6e87-461e-9182-41eaede1fab6"}],
          metadata_resource_type: ["EphemeraFolder"]
        }
      }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker_message2 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "1a2e9bef-e50d-4a9c-81f1-8d8e82f3a8e4",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => "e0d4e6f6-29f2-4fd7-9c8a-7293ae0d7689"}],
          metadata_resource_type: ["EphemeraFolder"]
        }
      }

      # Create a hydration cache entry from an ephemera folder message
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

      # Process deletion marker messages
      delete_messages =
        [
          ephemera_folder_deletion_marker_message,
          orphaned_deletion_marker_message1,
          orphaned_deletion_marker_message2
        ]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      # Only the deletion marker message that has a corresponding resource with
      # an exisiting hydration cache entry is handled by the default batcher.
      batchers = delete_messages |> Enum.map(&Map.get(&1, :batcher))
      assert batchers == [:default, :noop, :noop]

      # Send the one message with corresponding resource to the default batch handler.
      Figgy.HydrationConsumer.handle_batch(:default, [delete_messages |> hd], nil, %{
        cache_version: 1
      })

      # A transformed hydration cache entry is created which replaces the
      # existing ephemera folder hydration cache entry. It's metadata field
      # only has the value `deleted` set to true. This signals the
      # transformation consumer to create a transformation cache entry with a
      # solr record that indicates it should be deleted from the index.
      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1

      hydration_cache_entry = hydration_cache_entries |> hd
      assert hydration_cache_entry.data["internal_resource"] == "EphemeraFolder"
      assert hydration_cache_entry.record_id == ephemera_folder_message.data.id
      assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id
      assert hydration_cache_entry.data["metadata"]["deleted"] == true
    end

    test "handle_batch/3 deletes EphemeraFolders when their state or visibility change" do
      ephemera_folder_message_1 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
          updated_at: ~U[2025-04-18 14:28:57.52611Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
          }
        }
      }

      ephemera_folder_message_2 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "31732974-611e-4c06-8af3-928e553b6c9f",
          updated_at: ~U[2025-04-18 14:29:09.201335Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "ee769854-2d5f-4d79-81d9-3fdbb27fa168"}]
          }
        }
      }

      updated_visibility_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
          updated_at: ~U[2025-04-19 14:28:57.52611Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["restricted"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["restricted"],
            "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
          }
        }
      }

      updated_state_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "31732974-611e-4c06-8af3-928e553b6c9f",
          updated_at: ~U[2025-04-19 14:29:09.201335Z],
          internal_resource: "EphemeraFolder",
          state: ["pending"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["pending"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "ee769854-2d5f-4d79-81d9-3fdbb27fa168"}]
          }
        }
      }

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message_1, ephemera_folder_message_2]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

      # Process updated ephemera folder messages
      messages =
        [
          updated_visibility_ephemera_folder_message,
          updated_state_ephemera_folder_message
        ]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, messages, nil, %{cache_version: 1})

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
      assert hydration_cache_entry.record_id == ephemera_folder_message_2.data.id
      assert hydration_cache_entry.data["id"] == ephemera_folder_message_2.data.id
      assert hydration_cache_entry.data["metadata"]["deleted"] == true

      hydration_cache_entry = sorted_entries |> Enum.at(1)
      assert hydration_cache_entry.data["internal_resource"] == "EphemeraFolder"
      assert hydration_cache_entry.record_id == ephemera_folder_message_1.data.id
      assert hydration_cache_entry.data["id"] == ephemera_folder_message_1.data.id
      assert hydration_cache_entry.data["metadata"]["deleted"] == true
    end

    test "handle_batch/3 updates an EphemeraFolder when a related EphemeraTerm changes" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}],
            "genre" => [%{"id" => "01e15ce8-1a11-4342-b7b5-82cbff248b4d"}]
          }
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

      updated_ephemera_term_message = %Broadway.Message{
        acknowledger: nil,
        data: updated_ephemera_term_resource
      }

      file_set = IndexingPipeline.get_figgy_resource!("c42bca4b-02c9-44ad-b6bd-132ab27a8986")

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

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
        # Process updated ephemera term message
        messages =
          [updated_ephemera_term_message]
          |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

        Figgy.HydrationConsumer.handle_batch(:default, messages, nil, %{cache_version: 1})

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_term_message.data.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_term_message.data.id

        # Check updated term label
        related_resource_entry =
          hydration_cache_entry.related_data["resources"][updated_ephemera_term_resource.id]

        assert related_resource_entry["metadata"]["label"] == ["UpdatedTerm"]
      end
    end

    test "handle_batch/3 does not update an EphemeraFolder when a related resources changes but has an older timestamp" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}],
            "genre" => [%{"id" => "01e15ce8-1a11-4342-b7b5-82cbff248b4d"}]
          }
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

      updated_ephemera_term_message = %Broadway.Message{
        acknowledger: nil,
        data: updated_ephemera_term_resource
      }

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

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
        # Process updated ephemera term message
        messages =
          [updated_ephemera_term_message]
          |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))
          |> Enum.group_by(&Map.get(&1, :batcher))

        Figgy.HydrationConsumer.handle_batch(:default, messages[:batcher] || [], nil, %{
          cache_version: 1
        })

        Figgy.HydrationConsumer.handle_batch(:noop, messages[:noop] || [], nil, %{
          cache_version: 1
        })

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

        # Test that the ephemera folder was not updated
        assert hydration_cache_entry.source_cache_order !=
                 updated_ephemera_term_message.data.updated_at

        assert hydration_cache_entry.source_cache_order_record_id !=
                 updated_ephemera_term_message.data.id
      end
    end

    test "handle_batch/3 updates an EphemeraFolder when a related FileSet changes" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "05092b7d-d33c-4d4d-885e-b6b8973deec4",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "7b87fdfa-a760-49b9-85e9-093f2519f2fc"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "c42bca4b-02c9-44ad-b6bd-132ab27a8986"}]
          }
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

      updated_file_set_message = %Broadway.Message{
        acknowledger: nil,
        data: updated_file_set_resource
      }

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

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
        # Process updated file set message
        messages =
          [updated_file_set_message]
          |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

        Figgy.HydrationConsumer.handle_batch(:default, messages, nil, %{cache_version: 1})

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_file_set_message.data.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_file_set_message.data.id
      end
    end

    test "handle_batch/3 updates an EphemeraFolder when a parent EphemeraBox changes" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}],
            "title" => ["Folder"]
          }
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

      updated_ephemera_box_message = %Broadway.Message{
        acknowledger: nil,
        data: updated_ephemera_box_resource
      }

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

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
        # Process updated ephemera box message
        messages =
          [updated_ephemera_box_message]
          |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

        Figgy.HydrationConsumer.handle_batch(:default, messages, nil, %{cache_version: 1})

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_box_message.data.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_box_message.data.id

        # Check updated box number
        related_resource_entry =
          hydration_cache_entry.related_data["ancestors"][updated_ephemera_box_resource.id]

        assert related_resource_entry["metadata"]["box_number"] == ["different_box"]
      end
    end

    test "handle_batch/3 updates an EphemeraFolder when a grandparent EphemeraProject changes" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "561ea64a-9cd1-4994-b2a7-ac169f33ba84",
          updated_at: ~U[2024-04-18 14:28:57.526110Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "cached_parent_id" => [%{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "96f52803-f3d5-4cab-aba1-eceff648abdc"}],
            "title" => ["Folder"]
          }
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

      updated_ephemera_project_message = %Broadway.Message{
        acknowledger: nil,
        data: updated_ephemera_project_resource
      }

      # Create a hydration cache entry from ephemera folder messages
      create_messages =
        [ephemera_folder_message]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

      Figgy.HydrationConsumer.handle_batch(:default, create_messages, nil, %{cache_version: 1})

      hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
      assert hydration_cache_entries |> length == 1
      hydration_cache_entry = hydration_cache_entries |> Enum.at(0)
      assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

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
        # Process updated ephemera project message
        messages =
          [updated_ephemera_project_message]
          |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))

        Figgy.HydrationConsumer.handle_batch(:default, messages, nil, %{cache_version: 1})

        hydration_cache_entries = IndexingPipeline.list_hydration_cache_entries()
        assert hydration_cache_entries |> length == 1
        hydration_cache_entry = hydration_cache_entries |> Enum.at(0)

        assert hydration_cache_entry.data["id"] == ephemera_folder_message.data.id

        # Test that the ephemera folder was updated
        assert hydration_cache_entry.source_cache_order ==
                 updated_ephemera_project_message.data.updated_at

        assert hydration_cache_entry.source_cache_order_record_id ==
                 updated_ephemera_project_message.data.id

        # Check updated project title
        related_resource_entry =
          hydration_cache_entry.related_data["ancestors"][updated_ephemera_project_resource.id]

        assert related_resource_entry["metadata"]["title"] == ["Updated EphemeraProject Title"]
      end
    end
  end

  describe "hydration_cache_attributes/1" do
    test "it doesn't error when the related resource id is an empty string" do
      folder = FiggyTestSupport.first_ephemera_folder()

      related_resource_count =
        %Resource{folder | metadata: %{folder.metadata | "genre" => [%{"id" => ""}]}}
        |> HydrationConsumer.process(1)
        |> HydrationConsumer.hydration_cache_attributes(1)
        |> get_in([:related_data])
        |> get_in(["resources"])
        |> Map.keys()
        |> length()

      assert(related_resource_count == 24)
    end

    test "when there are no image members, the resource is marked for deletion" do
      folder = IndexingPipeline.get_figgy_resource!("f134f41f-63c5-4fdf-b801-0774e3bc3b2d")

      metadata =
        folder
        |> HydrationConsumer.process(1)
        |> HydrationConsumer.hydration_cache_attributes(1)
        |> get_in([:data])
        |> get_in([Access.key!(:metadata)])

      assert(metadata["deleted"] == true)
    end

    test "when there are no members at all, the resource is marked for deletion" do
      folder = IndexingPipeline.get_figgy_resource!("f134f41f-63c5-4fdf-b801-0774e3bc3b2d")

      metadata =
        %Resource{folder | metadata: %{folder.metadata | "member_ids" => []}}
        |> HydrationConsumer.process(1)
        |> HydrationConsumer.hydration_cache_attributes(1)
        |> get_in([:data])
        |> get_in([Access.key!(:metadata)])

      assert(metadata["deleted"] == true)
    end

    test "it filters out non-image members" do
      folder = IndexingPipeline.get_figgy_resource!("f134f41f-63c5-4fdf-b801-0774e3bc3b2d")

      member_ids = [
        # Video FileSet
        %{"id" => "e55355f9-a410-4f96-83d2-cfa165203d01"},
        # Image FileSet
        %{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}
      ]

      resource_ids =
        %Resource{folder | metadata: %{folder.metadata | "member_ids" => member_ids}}
        |> HydrationConsumer.process(1)
        |> HydrationConsumer.hydration_cache_attributes(1)
        |> get_in([:related_data])
        |> get_in(["resources"])
        |> Map.keys()

      assert("e55355f9-a410-4f96-83d2-cfa165203d01" not in resource_ids)
    end

    test "it filters out parent resources in related resources map" do
      folder = IndexingPipeline.get_figgy_resource!("26713a31-d615-49fd-adfc-93770b4f66b3")

      resource_ids =
        folder
        |> HydrationConsumer.process(1)
        |> HydrationConsumer.hydration_cache_attributes(1)
        |> get_in([:related_data])
        |> get_in(["resources"])
        |> Map.keys()

      assert("82624edb-c360-4d8a-b202-f103ee639e8e" not in resource_ids)
    end
  end
end
