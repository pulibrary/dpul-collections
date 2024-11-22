defmodule DpulCollections.ItemTest do
  use DpulCollections.DataCase

  alias DpulCollections.Item

  describe ".from_solr/1" do
    test "populates an empty array for image_service_urls if empty" do
      item = Item.from_solr(%{"title_ss" => ["Title"]})

      assert item.image_service_urls == []
    end
  end
end
