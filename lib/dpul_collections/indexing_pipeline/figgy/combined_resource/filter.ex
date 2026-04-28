defmodule DpulCollections.IndexingPipeline.Figgy.CombinedResource.Filter do
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry
  @indexable_resource_types ResourceTypeRegistry.indexable_types()
  @related_record_types ResourceTypeRegistry.related_record_types()

  @spec filter(resource :: %Figgy.Resource{}, cache_version :: integer()) :: [
          %Figgy.Resource{} | :skip
        ]
  # For records which can be related by something, grab resources for everything
  # we've already cached as CombinedResources.
  def filter(
        %Figgy.Resource{id: id, updated_at: updated_at, internal_resource: internal_resource},
        cache_version
      )
      when internal_resource in @related_record_types do
    IndexingPipeline.get_related_figgy_combined_resource_record_ids!(
      id,
      updated_at,
      cache_version
    )
    # Use a stream so we're not passing around every resource in memory.
    |> Stream.map(&IndexingPipeline.get_figgy_resource!(&1))
    |> Stream.map(&filter(&1, cache_version))
  end

  # Grab the full resource if we don't have it yet.
  def filter(
        resource = %Figgy.Resource{id: id, internal_resource: internal_resource, metadata: nil},
        cache_version
      )
      when internal_resource in @indexable_resource_types do
    IndexingPipeline.get_figgy_resource!(id)
    |> Figgy.Resource.populate_virtual()
    |> filter(cache_version)
  end

  # Scanned resources must be open, complete, and in the proper collection.
  def filter(
        resource = %Figgy.Resource{
          id: id,
          internal_resource: "ScannedResource",
          state: ["complete"],
          visibility: ["open"]
        },
        cache_version
      ) do
    if member_of_allowed_collection?(resource) do
      [resource]
    else
      [:skip]
    end
  end

  # Anything that's indexable and open/complete goes through.
  def filter(
        resource = %Figgy.Resource{
          id: id,
          internal_resource: internal_resource,
          state: ["complete"],
          visibility: ["open"]
        },
        cache_version
      )
      when internal_resource in @indexable_resource_types do
    [resource]
  end

  def filter(resource = %Figgy.Resource{}, _cache_version) do
    [:skip]
  end

  defp member_of_allowed_collection?(resource) do
    collection_ids = Enum.map(resource.member_of_collection_ids, & &1["id"])
    Enum.any?(collection_ids, &ResourceTypeRegistry.allowed_collection?/1)
  end
end
