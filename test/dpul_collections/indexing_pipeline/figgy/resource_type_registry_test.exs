defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistryTest do
  use ExUnit.Case, async: true
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry

  describe "indexable types" do
    test "indexable_types returns a list" do
      assert ResourceTypeRegistry.indexable_types() == ["EphemeraFolder", "ScannedResource"]
    end
  end

  describe "collection types" do
    test "collection_types returns the list" do
      assert ResourceTypeRegistry.collection_types() == ["EphemeraProject", "Collection"]
    end
  end

  describe "related record types" do
    test "related_record_types returns a list" do
      assert ResourceTypeRegistry.related_record_types() == [
               "EphemeraProject",
               "EphemeraBox",
               "EphemeraTerm",
               "FileSet"
             ]
    end
  end

  describe "transformable types" do
    test "transformable_types returns a list" do
      assert ResourceTypeRegistry.transformable_types() == [
               "EphemeraFolder",
               "ScannedResource",
               "EphemeraProject",
               "Collection"
             ]
    end
  end
end
