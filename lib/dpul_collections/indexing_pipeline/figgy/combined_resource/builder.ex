defmodule DpulCollections.IndexingPipeline.Figgy.CombinedResource.Builder do
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.CombinedResource.Related
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker

  @spec build(resources :: [%Figgy.CombinedResource{}], cache_version :: integer()) ::
          {:ok, [%Figgy.CombinedResource{}]} | {:error, :skip}
  def build(resources, cache_version) do
    resources
    |> Stream.map(&build_combined_resource(&1, cache_version))
    |> Stream.filter(fn resource -> resource != :skip end)
  end

  defp build_combined_resource(resource = %Figgy.Resource{}, cache_version) do
    %{
      related_data: related_data,
      related_data_markers: related_data_markers,
      related_ids: related_ids,
      persisted_member_ids: persisted_member_ids
    } = Related.from(resource)

    all_markers =
      [CacheEntryMarker.from(resource) | related_data_markers]
      |> Enum.sort(CacheEntryMarker)

    latest_marker = Enum.at(all_markers, -1)

    case persisted_member_ids do
      [] ->
        :skip

      _ ->
        %Figgy.CombinedResource{}
        |> Figgy.CombinedResource.changeset(%{
          cache_version: cache_version,
          record_id: resource.id,
          resource: resource,
          related_data: related_data,
          related_ids: related_ids,
          source_cache_order: latest_marker.timestamp,
          source_cache_order_record_id: latest_marker.id
        })
    end
  end

  defp build_combined_resource(:skip, _cache_version), do: :skip
end
