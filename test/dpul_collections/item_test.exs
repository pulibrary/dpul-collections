defmodule DpulCollections.ItemTest do
  alias DpulCollections.Solr
  import SolrTestSupport
  use DpulCollections.DataCase, async: true

  alias DpulCollections.Item

  describe ".from_solr/1" do
    test "populates an empty array for image_service_urls if empty" do
      item = Item.from_solr(%{"title_ss" => ["Title"]})

      assert item.image_service_urls == []
    end

    test "can build from an Ephemera Project" do
      id = "f99af4de-fed4-4baa-82b1-6e857b230306"
      FiggyTestSupport.index_record_id_directly(id)
      Solr.soft_commit()

      item = Item.from_solr(Solr.find_by_id(id))

      assert item.title == ["South Asian Ephemera"]
      assert item.slug == "sae"
      assert item.url == "/collections/sae"
    end
  end
end
