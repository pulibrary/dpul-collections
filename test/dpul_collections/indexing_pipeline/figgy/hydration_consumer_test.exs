defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumerTest do
  use DpulCollections.DataCase

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

      ephemera_folder_deletion_marker_message = %Broadway.Message{
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
          ephemera_folder_deletion_marker_message,
          file_set_deletion_marker_message
        ]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))
        |> Enum.map(&Map.get(&1, :batcher))

      assert transformed_messages == [:default, :noop, :noop, :default, :noop, :default, :noop]
    end
  end
end
