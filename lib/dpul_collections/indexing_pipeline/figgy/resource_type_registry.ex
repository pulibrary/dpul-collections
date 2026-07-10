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

  def indexable_types, do: @indexable_types
  def collection_types, do: @collection_types
  def related_record_types, do: @related_record_types
  def transformable_types, do: @transformable_types
  def processed_types, do: @processed_types
end
