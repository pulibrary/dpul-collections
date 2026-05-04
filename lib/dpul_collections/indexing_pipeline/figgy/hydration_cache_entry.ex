defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

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
end
