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
end
