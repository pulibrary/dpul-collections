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
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:genre_txtm] == ["Ephemera"]
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
