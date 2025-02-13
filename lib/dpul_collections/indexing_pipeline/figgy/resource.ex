defmodule DpulCollections.IndexingPipeline.Figgy.Resource do
  @moduledoc """
  Schema for a resource in the Figgy database
  """
  use Ecto.Schema
  alias DpulCollections.IndexingPipeline

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "orm_resources" do
    field :internal_resource, :string
    field :lock_version, :integer
    field :metadata, :map
    field :created_at, :utc_datetime_usec
    field :updated_at, :utc_datetime_usec
  end

  @type related_data() :: %{optional(field_name :: String.t()) => related_resource_map()}
  @type related_resource_map() :: %{
          optional(resource_id :: String.t()) => resource_struct :: map()
        }
  @spec to_hydration_cache_attrs(%__MODULE__{}) :: %{
          handled_data: map(),
          related_data: related_data()
        }
  def to_hydration_cache_attrs(resource = %__MODULE__{internal_resource: "DeletionMarker"}) do
    %{
      handled_data: resource |> to_map,
      related_data: %{}
    }
  end

  def to_hydration_cache_attrs(resource = %__MODULE__{internal_resource: "EphemeraTerm"}) do
    %{
      handled_data: resource |> to_map,
      related_data: %{}
    }
  end

  def to_hydration_cache_attrs(resource = %__MODULE__{internal_resource: "EphemeraFolder"}) do
    %{
      handled_data: resource |> to_map,
      related_data: extract_related_data(resource)
    }
  end

  @spec extract_related_data(resource :: %__MODULE__{}) :: related_data()
  def extract_related_data(resource) do
    %{
      "member_ids" => extract_members(resource)
    }
  end

  @spec extract_members(resource :: %__MODULE__{}) :: related_resource_map()
  defp extract_members(%{:metadata => %{"member_ids" => member_ids}}) do
    Enum.reduce(member_ids, %{}, &append_related_resource/2)
  end

  defp extract_members(_resource) do
    %{}
  end

  @spec append_related_resource(
          %{String.t() => resource_id :: String.t()},
          related_resource_map()
        ) :: related_resource_map()
  defp append_related_resource(%{"id" => id}, acc) do
    acc
    |> Map.put(
      id,
      IndexingPipeline.get_figgy_resource!(id) |> to_map()
    )
  end

  @spec to_map(resource :: %__MODULE__{}) :: map()
  defp to_map(resource = %__MODULE__{internal_resource: "DeletionMarker"}) do
    %{"resource_id" => [%{"id" => deleted_resource_id}]} = resource.metadata

    resource
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> Map.put(:id, deleted_resource_id)
  end

  defp to_map(resource = %__MODULE__{}) do
    resource
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end
end
