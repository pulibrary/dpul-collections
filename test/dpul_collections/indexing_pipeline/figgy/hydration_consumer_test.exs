defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumerTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  describe "Figgy.HydrationConsumer" do
    test "handle_message/3 only writes open and complete EphemeraFolders and EphemeraTerms to the Figgy.HydrationCache" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "state" => ["complete"],
            "visibility" => ["open"]
          }
        }
      }

      pending_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "state" => ["pending"],
            "visibility" => ["open"]
          }
        }
      }

      restricted_ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "state" => ["complete"],
            "visibility" => ["restricted"]
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
          metadata: %{
            "resource_id" => [%{"id" => "a521113e-e77a-4000-b00a-17c09b3aa757"}],
            "resource_type" => ["FileSet"]
          }
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
        |> Enum.map(&Map.get(&1, :batcher))

      assert transformed_messages == [:default, :noop, :noop, :default, :noop, :noop]
    end

    test "handle_batch/3 only processes deletion markers with related resources in the HydrationCache" do
      ephemera_folder_message = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "47276197-e223-471c-99d7-405c5f6c5285",
          updated_at: ~U[2018-03-09 20:19:34.486004Z],
          internal_resource: "EphemeraFolder",
          metadata: %{
            "state" => ["complete"],
            "visibility" => ["open"]
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
          metadata: %{
            "resource_id" => [%{"id" => "47276197-e223-471c-99d7-405c5f6c5285"}],
            "resource_type" => ["EphemeraFolder"]
          }
        }
      }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker_message1 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "f8f62bdf-9d7b-438f-9870-1793358e5fe1",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata: %{
            "resource_id" => [%{"id" => "fc8d345b-6e87-461e-9182-41eaede1fab6"}],
            "resource_type" => ["EphemeraFolder"]
          }
        }
      }

      # DeletionMarker that does not correspond to a resource with a hydration cache entry
      orphaned_deletion_marker_message2 = %Broadway.Message{
        acknowledger: nil,
        data: %Figgy.Resource{
          id: "1a2e9bef-e50d-4a9c-81f1-8d8e82f3a8e4",
          updated_at: ~U[2025-01-02 19:47:21.726083Z],
          internal_resource: "DeletionMarker",
          metadata: %{
            "resource_id" => [%{"id" => "e0d4e6f6-29f2-4fd7-9c8a-7293ae0d7689"}],
            "resource_type" => ["EphemeraFolder"]
          }
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
  end
end
