defmodule DpulCollections.IndexValidatorTest do
  use DpulCollections.DataCase
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
    end
  end
end
