defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

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
  end
end
