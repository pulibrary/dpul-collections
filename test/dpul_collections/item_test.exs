defmodule DpulCollections.ItemTest do
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr
  import SolrTestSupport
  use DpulCollections.DataCase

  alias DpulCollections.Item

  describe ".from_solr/1" do
    test "populates an empty array for image_service_urls if empty" do
      item = Item.from_solr(%{"title_ss" => ["Title"]})

      assert item.image_service_urls == []
    end

    setup do
      on_exit(fn -> Solr.delete_all(active_collection()) end)
    end

    test "can build from an Ephemera Project" do
      IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")
      |> Figgy.Resource.to_combined()
      |> Figgy.CombinedFiggyResource.to_solr_document()
      |> Solr.add()

      Solr.soft_commit()

      item = Item.from_solr(Solr.find_by_id("f99af4de-fed4-4baa-82b1-6e857b230306"))

      assert item.title == ["South Asian Ephemera"]
      assert item.slug == "sae"
      assert item.url == "/collections/sae"
    end
  end
end
