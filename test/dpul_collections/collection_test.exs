defmodule DpulCollections.CollectionTest do
  alias DpulCollections.Solr
  use DpulCollections.DataCase

  alias DpulCollections.Collection

  describe ".from_solr/1" do
    test "populates recent items" do
      sae_ids = [
        # Project
        "f99af4de-fed4-4baa-82b1-6e857b230306",
        # One Item
        "39a1a1a0-7ba6-4de9-8a44-f081811c2b34"
      ]

      # Add another ID so we know it doesn't include related items from other collections.
      other_ids = ["3da68e1c-06af-4d17-8603-fc73152e1ef7"]

      (sae_ids ++ other_ids)
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit()

      collection = Collection.from_slug("sae")

      assert length(collection.recently_updated) == 1
    end
  end
end
