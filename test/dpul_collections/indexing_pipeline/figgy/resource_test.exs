defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline.Figgy.Resource

  describe "to_hydration_cache_attrs/1" do
    test "it doesn't error when the related resource id is an empty string" do
      folder = FiggyTestSupport.first_ephemera_folder()

      related_resource_count =
        %Resource{folder | metadata: %{folder.metadata | "genre" => [%{"id" => ""}]}}
        |> Resource.to_hydration_cache_attrs()
        |> get_in([:related_data])
        |> get_in(["resources"])
        |> Map.keys()
        |> length()

      assert(related_resource_count == 20)
    end
  end
end
