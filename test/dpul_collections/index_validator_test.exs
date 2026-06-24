defmodule DpulCollections.IndexValidatorTest do
  use DpulCollections.DataCase, async: true
  alias DpulCollections.IndexValidator
  alias DpulCollections.Solr

  setup do
    [
      # sae project
      "f99af4de-fed4-4baa-82b1-6e857b230306",
      "e8abfa75-253f-428a-b3df-0e83ff2b20f9",
      "e379b822-27cc-4d0e-bca7-6096ac38f1e6"
    ]
    |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

    Solr.add([
      %{
        "id" => "extra-item",
        "title_txtm" => ["test title 1"],
        "collection_titles_ss" => ["South Asian Ephemera"]
      }
    ])

    Solr.soft_commit(active_collection())

    :ok
  end

  describe ".all_collections" do
    test "returns a list of IndexValidator structs" do
      validators = IndexValidator.all_collections()
      assert length(validators) == 1

      sae_validator = hd(validators)
      assert sae_validator.dc_count == 3

      # 1 is reading-room, so it gets filtered out.
      # 1 has no member_ids, so it should get filtered out.
      assert sae_validator.public_complete_figgy_count == 15

      assert length(sae_validator.missing_items) == 13
      assert Enum.member?(sae_validator.missing_items, "d82efa97-c69b-424c-83c2-c461baae8307")

      assert length(sae_validator.extra_items) == 1
      assert Enum.member?(sae_validator.extra_items, "extra-item")
    end
  end
end
