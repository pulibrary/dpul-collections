defmodule DpulCollections.IndexingPipeline.Figgy.DeletionRecord do
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  defstruct [:marker, :internal_resource, :id]

  def from(
        resource = %{
          internal_resource: "DeletionMarker",
          metadata_resource_id: [%{"id" => resource_id}],
          metadata_resource_type: [resource_type]
        }
      ) do
    %__MODULE__{
      marker: CacheEntryMarker.from(resource),
      internal_resource: resource_type,
      id: resource_id
    }
  end

  def from(resource = %{internal_resource: internal_resource, id: id}) do
    %__MODULE__{
      marker: CacheEntryMarker.from(resource),
      internal_resource: internal_resource,
      id: id
    }
  end

  def from(combined_resource = %Figgy.CombinedFiggyResource{}) do
    %__MODULE__{
      marker: combined_resource.latest_updated_marker,
      internal_resource: combined_resource.resource.internal_resource,
      id: combined_resource.resource.id
    }
  end
end
