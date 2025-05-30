defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  describe "Figgy.HydrationConsumer" do
    test "handle_message/3 when a message is not a complete and visible EphemeraFolder, it is sent to noop batcher" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "state" => ["complete"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}]
          }
        }
      }

      pending_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          state: ["pending"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "state" => ["pending"],
            "visibility" => ["open"],
            "member_ids" => [%{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}]
          }
        }
      }

      restricted_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["restricted"],
          metadata: %{
            "title" => ["title"],
            "state" => ["complete"],
            "visibility" => ["restricted"],
            "member_ids" => [%{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}]
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
          id: "69990556-434c-476a-9043-bbf9a1bda5a4",
          updated_at: ~U[2018-03-09 20:19:34.465203Z],
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
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          state: ["complete"],
          visibility: ["open"],
          metadata: %{
            "title" => ["title"],
            "visibility" => ["open"],
            "state" => ["complete"],
            "member_ids" => [%{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}]
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
          metadata_resource_id: [%{"id" => "47276197-e223-471c-99d7-405c5f6c5285"}],
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
  end
end
