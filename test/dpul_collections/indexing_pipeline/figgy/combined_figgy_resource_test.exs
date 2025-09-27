defmodule DpulCollections.IndexingPipeline.Figgy.CombinedFiggyResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  describe "#to_solr_document" do
    test "converting an EphemeraProject" do
      doc =
        IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert %{
               id: "f99af4de-fed4-4baa-82b1-6e857b230306",
               title_txtm: ["South Asian Ephemera"],
               resource_type_s: "collection",
               tagline_txt_sort: [
                 "Discover voices of change across South Asia through contemporary pamphlets, flyers, and documents that capture the region's social movements, politics, and cultural expressions."
               ],
               authoritative_slug_s: "sae"
             } = doc

      assert hd(doc[:description_txtm]) =~ "already robust <a"
    end

    test "converting a featurable EphemeraFolder sets a boolean" do
      doc =
        IndexingPipeline.get_figgy_resource!("e8abfa75-253f-428a-b3df-0e83ff2b20f9")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert %{
               featurable_b: true
             } = doc

      unfeatured_doc =
        IndexingPipeline.get_figgy_resource!("3da68e1c-06af-4d17-8603-fc73152e1ef7")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert unfeatured_doc[:featurable_b] == false
    end
  end
end
