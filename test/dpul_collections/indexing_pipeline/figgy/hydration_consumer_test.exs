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

      transformed_messages =
        [
          ephemera_folder_message,
          pending_ephemera_folder_message,
          restricted_ephemera_folder_message,
          ephemera_term_message,
          scanned_resource_message
        ]
        |> Enum.map(&Figgy.HydrationConsumer.handle_message(nil, &1, %{cache_version: 1}))
        |> Enum.map(&Map.get(&1, :batcher))

      assert transformed_messages == [:default, :noop, :noop, :default, :noop]
    end
  end
end
