defmodule DpulCollections.IndexingPipeline.Figgy.Resource do
  @moduledoc """
  Schema for a resource in the Figgy database
  """
  use Ecto.Schema
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  @derive {Jason.Encoder, except: [:__meta__]}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "orm_resources" do
    field :internal_resource, :string
    field :lock_version, :integer
    field :metadata, :map
    field :created_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec
    # These are propagated by get_figgy_resources_since! to prevent pulling all
    # of metadata.
    field :visibility, {:array, :string}, virtual: true
    field :state, {:array, :string}, virtual: true
    field :metadata_resource_id, {:array, :map}, virtual: true
    field :metadata_resource_type, {:array, :string}, virtual: true
  end

  @type related_data() :: %{optional(field_name :: String.t()) => related_resource_map()}
  @type related_resource_map() :: %{
          optional(resource_id :: String.t()) => resource_struct :: map()
        }

  def populate_virtual(
        resource = %__MODULE__{
          metadata: metadata = %{"state" => state, "visibility" => visibility}
        }
      ) do
    %{
      resource
      | state: state,
        visibility: visibility,
        metadata_resource_id: metadata[:resource_id],
        metadata_resource_type: metadata[:resource_type]
    }
  end

  @spec to_hydration_cache_attrs(%__MODULE__{}) :: %{
          handled_data: map(),
          related_data: related_data()
        }
  # We haven't pulled the full resource yet, so grab it.
  def to_hydration_cache_attrs(%__MODULE__{
        id: id,
        internal_resource: "EphemeraFolder",
        metadata: nil
      }) do
    IndexingPipeline.get_figgy_resource!(id)
    |> to_hydration_cache_attrs
  end

  def to_hydration_cache_attrs(resource = %__MODULE__{internal_resource: "EphemeraFolder"}) do
    combined_resource = Figgy.CombinedFiggyResource.from(resource)
    related_data = combined_resource.related_data

    handled_data =
      if combined_resource.persisted_member_ids == [] do
        %{resource | metadata: %{"deleted" => true}}
      else
        resource
      end

    %{
      handled_data: handled_data,
      related_data: related_data,
      related_ids: combined_resource.related_ids,
      source_cache_order: combined_resource.latest_updated_marker.timestamp,
      source_cache_order_record_id: combined_resource.latest_updated_marker.id
    }
  end
end
