defmodule DpulCollections.IndexingPipeline.HydrationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hydration_cache_entries" do
    field :data, :map
    field :cache_version, :integer
    field :record_id, :string
    field :source_cache_order, :utc_datetime

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(hydration_cache_entry, attrs) do
    hydration_cache_entry
    |> cast(attrs, [:data, :cache_version, :record_id, :source_cache_order])
    |> validate_required([:data, :cache_version, :record_id, :source_cache_order])
  end
end
