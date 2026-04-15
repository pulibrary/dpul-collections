defmodule DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry do
  @moduledoc """
  Registry for the Figgy resource types that the pipeline handles
  """

  # Primary item resource types
  @indexable_types ["EphemeraFolder", "ScannedResource"]

  # Types of resources that behave as collections
  @collection_types ["EphemeraProject", "Collection"]

  # Types that trigger re-indexing of related records
  @related_record_types ["EphemeraProject", "EphemeraBox", "EphemeraTerm", "FileSet"]

  # Types used in the transformation pipeline
  @transformable_types @indexable_types ++ @collection_types

  # Temporary restrictions to allow gradual ingest of different types
  @allowed_collections ["52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a"]

  def indexable_types, do: @indexable_types
  def collection_types, do: @collection_types
  def related_record_types, do: @related_record_types
  def transformable_types, do: @transformable_types
  def allowed_collection?(id), do: id in @allowed_collections
end
