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
  @allowed_scanned_resources ["27fd4d29-1170-47a5-891b-f2743873bcef", "72507ee3-850b-4ad6-9098-141257cb319f", "ee3528e9-88a4-4d2b-adee-f05efede87a7", "1a8c14ca-060c-434f-b999-6191db4c336c", "2cc9b5cf-8d33-4f1b-b53f-fcc658770458"]

  def indexable_types, do: @indexable_types
  def collection_types, do: @collection_types
  def related_record_types, do: @related_record_types
  def transformable_types, do: @transformable_types
  def allowed_scanned_resource_count, do: length(@allowed_scanned_resources)
  def allowed_collection?(id), do: id in @allowed_collections
  def allowed_scanned_resource?(id), do: id in @allowed_scanned_resources
end
