defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry do
  @moduledoc """
  Registry for the Figgy resource types that the pipeline handles
  """

  # Primary item resource types
  @indexable_types ["EphemeraFolder", "ScannedResource"]

  # Types of resources that behave as collections
  @collection_types ["EphemeraProject", "Collection"]

  # Types that trigger re-indexing of related records
  @related_record_types [
    "EphemeraProject",
    "Collection",
    "EphemeraBox",
    "EphemeraTerm",
    "FileSet"
  ]

  # Types used in the transformation pipeline
  @transformable_types @indexable_types ++ @collection_types

  # Types that are processed at all.
  @processed_types @indexable_types ++
                     @collection_types ++ @related_record_types ++ ["DeletionMarker"]

  # Temporary restrictions to allow gradual ingest of different types
  @allowed_collections [
    # Manuscripts of the Islamic World
    "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
    # Mesoamerican Manuscripts
    "29f05b11-1932-4031-b20d-cad98f80e3bc",
    # Medieval and Renaissance Manuscripts
    "bc89f42f-d1ee-4338-80bc-a95b036024e4"
  ]

  def indexable_types, do: @indexable_types
  def collection_types, do: @collection_types
  def related_record_types, do: @related_record_types
  def transformable_types, do: @transformable_types
  def processed_types, do: @processed_types
  def allowed_collection?(id), do: id in @allowed_collections
end
