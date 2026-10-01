defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  describe "converting to solr" do
    test "it's possible to convert a folder to a solr document without the pipeline" do
      folder = IndexingPipeline.get_figgy_resource!("be12221a-6461-4aae-a6c6-c1defc8717dd")

      doc =
        folder
        |> Figgy.Resource.to_combined()
        |> Figgy.SolrDocument.from_combined_figgy_resource()

      assert doc[:format_txt_sort] == ["Ephemera"]
    end
  end

  describe "populate_virtual/1" do
    test "returns resource unchanged when metadata has no visibility or state" do
      resource = IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")
      assert Figgy.Resource.populate_virtual(resource) == resource
    end
  end

  describe ".to_combined()" do
    test "it grabs vocabularies/categories into related_data" do
      folder = IndexingPipeline.get_figgy_resource!("26713a31-d615-49fd-adfc-93770b4f66b3")

      combined_resource = folder |> Figgy.Resource.to_combined()

      refute combined_resource.related_data["resources"]["277cdbea-c0a8-4b7f-8bf6-de5ac07f95c3"] ==
               nil
    end
    test "pulls thumbnails in for ephemera folders" do
      folder = IndexingPipeline.get_figgy_resource!("26713a31-d615-49fd-adfc-93770b4f66b3")

      combined_resource = folder |> Figgy.Resource.to_combined()

      thumbnail = combined_resource.related_data["thumbnail"]

      assert %{id: "d798d940-0740-4854-8f70-60217ec8c2e4"} = thumbnail

    end
    test "it pulls in thumbnails for MVWs" do
      combined_resource =
        IndexingPipeline.get_figgy_resource!("a9f3fc2a-24e8-4787-b932-0245453f3810")
        |> Figgy.Resource.to_combined()

      thumbnail = combined_resource.related_data["thumbnail"]
      assert %{id: "e55ce0e5-187c-4c7e-8079-03a571e4f16b"} = thumbnail
    end
  end
end
