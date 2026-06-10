defmodule DpulCollections.IndexValidatorTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexValidator
  alias DpulCollections.Solr
  alias DpulCollections.Item

  setup do
    [
      # sae project
      "f99af4de-fed4-4baa-82b1-6e857b230306",
      "e8abfa75-253f-428a-b3df-0e83ff2b20f9",
      "e379b822-27cc-4d0e-bca7-6096ac38f1e6"
    ]
    |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

    Solr.soft_commit(active_collection())

    on_exit(fn -> Solr.delete_all(active_collection()) end)
    :ok
  end

  describe ".all_collections" do
    test "returns a list of IndexValidator structs" do
      validators = IndexValidator.all_collections()
      assert length(validators) == 1

      sae_validator = hd(validators)
      assert sae_validator.dc_count == 2

      assert sae_validator.total_figgy_count == 15

      # assert sae_validator.filtered_items == [%Item{id: "8691231a-d06f-4fa2-af5b-d773310564a3", title: "Martyrs of Pakistan Navy : Defence and Martyrs Day 2023"}]
      # TODO: but later 12
      assert length(sae_validator.missing_items) == 13
      assert Enum.member?(sae_validator.missing_items, "d82efa97-c69b-424c-83c2-c461baae8307")
      # TODO: Test setup for extra items. Add something to Solr via Solr.add
      # with a map and the collection name.
    end
  end
end
