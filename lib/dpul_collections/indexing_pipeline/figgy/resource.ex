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
  def extract_related_data(%__MODULE__{
        metadata: %{"state" => [state], "visibility" => [visibility]}
      })
      when state != "complete" or visibility != "open" do
    %{}
  end

  def extract_related_data(resource) do
    %{
      "member_ids" => extract_members(resource)
    }
  end

  @spec extract_members(resource :: %__MODULE__{}) :: related_resource_map()
  defp extract_members(resource = %{:metadata => %{"member_ids" => _member_ids}}) do
    # Enum.reduce(member_ids, %{}, &append_related_resource/2)
    # get just the list of members
    # turn it into a map of id => FiggyResource
    IndexingPipeline.get_figgy_members(resource.id)
    |> Enum.map(fn m -> {m.id, to_map(m)} end)
    |> Map.new()
  end

  # there are no member_ids
  defp extract_members(_resource) do
    %{}
  end

  @spec to_map(resource :: %__MODULE__{}) :: map()
  defp to_map(resource = %__MODULE__{internal_resource: "DeletionMarker"}) do
    %{
      "resource_id" => [%{"id" => deleted_resource_id}],
      "resource_type" => [deleted_resource_type]
    } = resource.metadata

    %{
      id: deleted_resource_id,
      internal_resource: deleted_resource_type,
      lock_version: resource.lock_version,
      created_at: resource.created_at,
      updated_at: resource.updated_at,
      metadata: %{"deleted" => true}
    }
  end

  @spec to_map(resource :: %__MODULE__{}) :: map()
  defp to_map(
         resource = %__MODULE__{metadata: %{"state" => [state], "visibility" => [visibility]}}
       )
       when state != "complete" or visibility != "open" do
    %{
      id: resource.id,
      internal_resource: resource.internal_resource,
      lock_version: resource.lock_version,
      created_at: resource.created_at,
      updated_at: resource.updated_at,
      metadata: %{"deleted" => true}
    }
  end

  defp to_map(resource = %__MODULE__{}) do
    resource
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end
end
