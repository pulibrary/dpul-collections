defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry do
  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
  alias DpulCollections.IndexingPipeline.Figgy
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

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

  @spec to_solr_document(%__MODULE__{}) :: %{}
  def to_solr_document(cache_entry = %HydrationCacheEntry{}) do
    cache_entry
    |> HydrationCacheEntry.to_combined_figgy_resource()
    |> Figgy.CombinedFiggyResource.to_solr_document()
  end

  @spec to_combined_figgy_resource(%HydrationCacheEntry{}) :: %Figgy.CombinedFiggyResource{}
  def to_combined_figgy_resource(%__MODULE__{
        data: data,
        related_data: related_data,
        related_ids: related_ids
      }) do
    %Figgy.CombinedFiggyResource{
      resource: data,
      related_data: related_data,
      related_ids: related_ids
    }
  end
end
