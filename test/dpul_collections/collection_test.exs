defmodule DpulCollections.CollectionTest do
  alias DpulCollections.Solr
  use DpulCollections.DataCase

  alias DpulCollections.Collection

  describe ".from_solr/1" do
    test "converts headings" do
      FiggyTestSupport.index_record_id_directly("f99af4de-fed4-4baa-82b1-6e857b230306")
      Solr.soft_commit()

      collection = Collection.from_slug("sae")

      assert collection.summary =~ "<h3"
      assert collection.summary =~ "</h3"
      refute collection.summary =~ "<br>"
    end

    test "if there are not enough featured items, it gets recent items" do
      sae_ids = [
        # Project
        "f99af4de-fed4-4baa-82b1-6e857b230306",
        # Highlighted item
        "d82efa97-c69b-424c-83c2-c461baae8307",
        # Non-highlighted item
        "31aafb19-eaca-4d02-9780-2ee76b146663"
      ]

      # Add another ID so we know it doesn't include related items from other collections.
      other_ids = ["3da68e1c-06af-4d17-8603-fc73152e1ef7"]

      (sae_ids ++ other_ids)
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit()

      collection = Collection.from_slug("sae")

      assert length(collection.banner_items) == 2
    end

    test "if there are no items, banner_item is nil" do
      coll_ids = [
        # Middle East Manuscripts
        "3bab572e-6603-4abf-8305-16ce6fe3ac5c"
      ]

      # Add another ID so we know it doesn't include related items from other collections.
      other_ids = ["3da68e1c-06af-4d17-8603-fc73152e1ef7"]

      (coll_ids ++ other_ids)
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit()

      collection = Collection.from_slug("middle-east-mss") |> Collection.load_related_records()

      assert length(collection.banner_items) == 0
      assert collection.banner_item == nil
      assert Collection.banner_source(collection) == nil
    end
  end

  describe ".load_related_records" do
    test "populates recent items" do
      sae_ids = [
        # Project
        "f99af4de-fed4-4baa-82b1-6e857b230306",
        # One Item
        "d82efa97-c69b-424c-83c2-c461baae8307"
      ]

      # Add another ID so we know it doesn't include related items from other collections.
      other_ids = ["3da68e1c-06af-4d17-8603-fc73152e1ef7"]

      (sae_ids ++ other_ids)
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit()

      collection = Collection.from_slug("sae") |> Collection.load_related_records()

      assert length(collection.recently_added) == 1
    end
  end

  describe ".authoritative_slug_from_title/1" do
    test "returns the authoritative slug when a collection with the given title is indexed" do
      Solr.add(
        [
          %{
            id: "d7c889ba-9992-494e-8fe4-2c4a9b3c3d7d",
            title_txtm: ["Latin American Ephemera"],
            resource_type_s: "collection",
            authoritative_slug_s: "lae"
          }
        ],
        SolrTestSupport.active_collection()
      )

      Solr.soft_commit()

      assert Collection.authoritative_slug_from_title("Latin American Ephemera") == "lae"
    end

    test "returns nil when no collection matches the title" do
      assert Collection.authoritative_slug_from_title("Unindexed Collection") == nil
    end
  end

  describe ".get_contributors/1" do
    test "returns 3 contributors for lae" do
      assert length(Collection.get_contributors("lae")) == 3
    end

    test "returns 1 contributor for SAE" do
      assert length(Collection.get_contributors("sae")) == 1
    end

    test "returns no contributors for unknown slugs" do
      assert length(Collection.get_contributors("notarealslug")) == 0
    end
  end
end
