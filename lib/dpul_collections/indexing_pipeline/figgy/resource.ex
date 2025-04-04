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
      "parent_ids" => extract_parents(resource),
      "resources" => fetch_related(resource)
    }
  end

  @doc """
  Finds all metadata properties which contain references to related resources
  (those with the form `[%{"id" => id}]` and then fetches those resources from Figgy
  in a single query.

  ## Example

  ```
  r = %Figgy.Resource{
        id: "097263fb-5beb-407b-ab36-b468e0489792",
        internal_resource: "EphemeraFolder",
        metadata: %{
          "genre": [%{"id" => "668a21d7-750d-477d-b569-54ad511f13d7"}],
          "member_ids": [%{"id" => "557cc7c1-9852-471b-ae4d-f1c14be3890b"}]
        }
      }

  fetch_related(r)

  Returns:
  %{
    "668a21d7-750d-477d-b569-54ad511f13d7" => %{
      "id" => "668a21d7-750d-477d-b569-54ad511f13d7",
      "internal_resource" => "EphemeraTerm",
      "metadata" => %{
        "label" => ["a genre"]
      }
    },
    "557cc7c1-9852-471b-ae4d-f1c14be3890b" => %{
      "id" => "557cc7c1-9852-471b-ae4d-f1c14be3890b",
      "internal_resource: "FileSet",
      "metadata" => %{
        "file_metadata" => [
          %{
            "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4017"},
            "internal_resource" => "FileMetadata",
            "mime_type" => ["image/tiff"],
            "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
          }
        ]
      }
    }
  """
  @spec fetch_related(%__MODULE__{}) :: related_data()
  defp fetch_related(%__MODULE__{metadata: metadata}) do
    metadata
    # Get the metadata property names
    |> Map.keys()
    # Map the values of each property into a list
    |> Enum.map(fn key -> metadata[key] end)
    # Flatten nested lists into a single list
    |> Enum.concat()
    # If the value has the form `%{"id" => id}`, then extract the id string from map
    |> Enum.map(&extract_ids_from_value/1)
    # Remove nil and empty string values
    |> Enum.filter(fn id -> !is_nil(id) and id != "" end)
    # Query figgy using the resulting list of ids
    |> IndexingPipeline.get_figgy_resources()
    # Map the returned Figgy.Resources into tuples of this form:
    # `{resource_id, %{"name" => value, ..}}`
    |> Enum.map(fn m -> {m.id, to_map(m)} end)
    # Convert the list of tuples into a map with the form:
    # `%{"id-1" => %{ "name" => "value", ..}, %{"id-2" => {"name" => "value", ..}}, ..}`
    |> Map.new()
  end

  # Extract an id string from a value map.
  # Exclude values that have more than one key. These are field like
  # pending_upload which should not be extracted a related resources.
  defp extract_ids_from_value(value = %{"id" => id}) when map_size(value) == 1, do: id

  defp extract_ids_from_value(_), do: nil

  @spec extract_parents(resource :: %__MODULE__{}) :: related_resource_map()
  defp extract_parents(resource = %{:metadata => %{"cached_parent_id" => _cached_parent_id}}) do
    # turn it into a map of id => FiggyResource
    IndexingPipeline.get_figgy_parents(resource.id)
    |> Enum.map(fn m -> {m.id, to_map(m)} end)
    |> Map.new()
  end

  # there isn't a parent
  defp extract_parents(_resource) do
    %{}
  end

  @spec to_map(resource :: %__MODULE__{}) :: map()
  defp to_map(
         resource = %__MODULE__{
           internal_resource: "DeletionMarker",
           metadata_resource_id: [%{"id" => deleted_resource_id}],
           metadata_resource_type: [deleted_resource_type]
         }
       ) do
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
         resource = %__MODULE__{
           internal_resource: "EphemeraFolder",
           metadata: %{"state" => [state], "visibility" => [visibility]}
         }
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
