defmodule DpulCollections.IndexingPipeline.Figgy.ImportedCatalogSchemaTest do
  use DpulCollections.DataCase, async: true
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy.ImportedCatalogSchema

  describe "struct instantiation" do
    test "can be instantiated from a ScannedResource's imported metadata" do
      resource = IndexingPipeline.get_figgy_resource!("27fd4d29-1170-47a5-891b-f2743873bcef")
      imported_schema = ImportedCatalogSchema.from_resource(resource)
      assert imported_schema.author == ["Ṣaffūrī, ʻAlī ibn ʻAbd al-Raḥmān"]
    end
  end
end
