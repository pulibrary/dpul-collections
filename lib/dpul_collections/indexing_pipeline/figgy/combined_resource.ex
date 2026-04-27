defmodule DpulCollections.IndexingPipeline.Figgy.CombinedResource do
  alias DpulCollections.IndexingPipeline.Figgy.CombinedResource
  alias DpulCollections.IndexingPipeline.Figgy
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  schema "figgy_combined_resources" do
    field :resource, :map
    field :related_data, :map, default: %{}
    field :record_id, :string
    field :related_ids, {:array, :string}, default: []
    # Cache Fields
    field :cache_version, :integer
    field :source_cache_order, :utc_datetime_usec
    field :source_cache_order_record_id, :string

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(combined_resource, attrs) do
    combined_resource
    |> cast(attrs, [
      :resource,
      :related_data,
      :record_id,
      :related_ids,
      :cache_version,
      :source_cache_order,
      :source_cache_order_record_id
    ])
    |> validate_required([
      :resource,
      :cache_version,
      :record_id,
      :related_ids,
      :source_cache_order,
      :source_cache_order_record_id
    ])
  end

  @spec to_solr_document(%__MODULE__{}) :: %{}
  def to_solr_document(cache_entry = %CombinedResource{}) do
    cache_entry
    |> CombinedResource.to_combined_figgy_resource()
    |> Figgy.CombinedFiggyResource.to_solr_document()
  end

  @spec to_combined_figgy_resource(%CombinedResource{}) :: %Figgy.CombinedFiggyResource{}
  def to_combined_figgy_resource(%__MODULE__{
        resource: data,
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
