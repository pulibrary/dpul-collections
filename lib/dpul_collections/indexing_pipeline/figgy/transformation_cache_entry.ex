defmodule DpulCollections.IndexingPipeline.Figgy.TransformationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "figgy_transformation_cache_entries" do
    field :data, :map
    field :cache_version, :integer
    field :record_id, :string
    field :source_cache_order, :utc_datetime_usec

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(transformation_cache_entry, attrs) do
    transformation_cache_entry
    |> cast(attrs, [:data, :cache_version, :record_id, :source_cache_order])
    |> validate_required([:data, :cache_version, :record_id, :source_cache_order])
  end
end
