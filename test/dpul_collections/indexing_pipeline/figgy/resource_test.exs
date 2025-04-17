defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
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

    test "when there are no image members, the resource is marked for deletion" do
      folder = IndexingPipeline.get_figgy_resource!("f134f41f-63c5-4fdf-b801-0774e3bc3b2d")

      metadata =
        folder
        |> Resource.to_hydration_cache_attrs()
        |> get_in([:handled_data])
        |> get_in([:metadata])

      assert(metadata["deleted"] == true)
    end

    test "it filters out non-image members" do
      folder = IndexingPipeline.get_figgy_resource!("f134f41f-63c5-4fdf-b801-0774e3bc3b2d")

      member_ids = [
        # Video FileSet
        %{"id" => "e55355f9-a410-4f96-83d2-cfa165203d01"},
        # Image FileSet
        %{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}
      ]

      resource_ids =
        %Resource{folder | metadata: %{folder.metadata | "member_ids" => member_ids}}
        |> Resource.to_hydration_cache_attrs()
        |> get_in([:related_data])
        |> get_in(["resources"])
        |> Map.keys()

      assert("e55355f9-a410-4f96-83d2-cfa165203d01" not in resource_ids)
    end
  end
end
