defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset
  alias DpulCollections.IndexingPipeline.Figgy

  schema "figgy_hydration_cache_entries" do
    field :data, :map
    field :related_data, :map, default: %{}
    field :cache_version, :integer
    field :record_id, :string
    field :related_ids, {:array, :string}, default: []
    field :source_cache_order, :utc_datetime_usec
    field :source_cache_order_record_id, :string

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(hydration_cache_entry, attrs) do
    hydration_cache_entry
    |> cast(attrs, [
      :data,
      :related_data,
      :cache_version,
      :record_id,
      :related_ids,
      :source_cache_order,
      :source_cache_order_record_id
    ])
    |> validate_required([
      :data,
      :cache_version,
      :record_id,
      :related_ids,
      :source_cache_order,
      :source_cache_order_record_id
    ])
  end

  # store in HydrationCache:
  # - cache_version (this only changes manually, we have to hold onto it as state)
  # - record_id (varchar) - the figgy UUID
  # - data (blob) - this is the record
  # - related_data (blob) - map of related data
  # - related_ids (array<string>) - array of IDs that are contained in
  #   related_data
  # - source_cache_order (datetime) - most recent figgy or related resource updated_at
  # - source_cache_order_record_id (varchar) - record id of the source_cache_order value
  @spec from(
          %Figgy.DeletionRecord{} | %Figgy.CombinedFiggyResource{},
          cache_version :: integer
        ) :: %__MODULE__{}
  def from(
        %Figgy.DeletionRecord{
          marker: marker,
          id: id,
          internal_resource: internal_resource
        },
        cache_version
      ) do
    %__MODULE__{
      cache_version: cache_version,
      record_id: id,
      related_ids: [],
      source_cache_order: marker.timestamp,
      source_cache_order_record_id: marker.id,
      data: %{internal_resource: internal_resource, id: id, metadata: %{"deleted" => true}}
    }
  end

  def from(uncombined_resource = %Figgy.Resource{}, cache_version) do
    from(Figgy.Resource.to_combined(uncombined_resource), cache_version)
  end

  def from(
        combined_resource = %Figgy.CombinedFiggyResource{resource: resource},
        cache_version
      ) do
    %__MODULE__{
      cache_version: cache_version,
      record_id: resource.id,
      data: resource,
      related_data: combined_resource.related_data,
      related_ids: combined_resource.related_ids,
      source_cache_order: combined_resource.latest_updated_marker.timestamp,
      source_cache_order_record_id: combined_resource.latest_updated_marker.id
    }
  end
end
