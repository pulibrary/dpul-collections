defmodule DpulCollections.IndexingPipeline.FiggyHydratorTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyHydrator
  alias DpulCollections.IndexingPipeline.FiggyProducer
  alias DpulCollections.IndexingPipeline

  describe "FiggyHydrator" do
    test "handle_message/3" do
      initial_state = %{last_queried_marker: nil}
      {:noreply, [message], _} = FiggyProducer.handle_demand(1, initial_state)
      data = message.data
      ref = Broadway.test_message(FiggyHydrator, data)
      assert_receive {:ack, ^ref, [%{data: ^data}], []}

      cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd




      # assert cache_entry.data == 1
      # %DpulCollections.IndexingPipeline.FiggyResource{__meta__: #Ecto.Schema.Metadata<:loaded, "orm_resources">, id: "3cb7627b-defc-401b-9959-42ebc4488f74", internal_resource: "EphemeraTerm", lock_version: nil, metadata: %{"code" => ["ja"], "edit_groups" => [], "edit_users" => [], "label" => ["Japan"], "lcsh_label" => [], "member_of_vocabulary_id" => [%{"id" => "22597862-062b-4c91-a6ca-cd73a30aceb1"}], "new_record" => false, "read_groups" => [], "read_users" => [], "tgm_label" => [], "uri" => []}, created_at: ~U[2018-02-22 19:13:49.949551Z], updated_at: ~U[2018-03-09 20:19:33.414040Z]}
    end
  end
end
