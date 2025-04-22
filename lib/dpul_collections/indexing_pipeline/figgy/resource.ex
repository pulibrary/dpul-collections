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

  def to_hydration_cache_attrs(
        resource = %__MODULE__{
          internal_resource: "EphemeraFolder",
          metadata: %{"visibility" => ["restricted"]}
        }
      ) do
    %{
      handled_data: resource |> to_map(delete: true),
      related_data: %{}
    }
  end

  def to_hydration_cache_attrs(
        resource = %__MODULE__{
          internal_resource: "EphemeraFolder",
          metadata: %{"state" => [state]}
        }
      )
      when state != "complete" do
    related_parent_map = extract_parent(resource)

    if parent_state(related_parent_map) == ["all_in_production"] do
      %{
        handled_data: resource |> to_map,
        related_data: %{
          "parent_ids" => related_parent_map,
          "resources" => fetch_related(resource)
        }
      }
    else
      %{
        handled_data: resource |> to_map(delete: true),
        related_data: %{}
      }
    end
  end

  def to_hydration_cache_attrs(resource = %__MODULE__{internal_resource: "EphemeraFolder"}) do
    related_resources = fetch_related(resource)

    handled_data =
      if resource_empty?(resource, related_resources) do
        resource |> to_map(delete: true)
      else
        resource |> to_map
      end

    %{
      handled_data: handled_data,
      related_data: %{
        "parent_ids" => extract_parent(resource),
        "resources" => related_resources
      }
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
    |> remove_non_displayable_filesets()
    # Map the returned Figgy.Resources into tuples of this form:
    # `{resource_id, %{"name" => value, ..}}`
    |> Enum.map(fn m -> {m.id, to_map(m)} end)
    # Convert the list of tuples into a map with the form:
    # `%{"id-1" => %{ "name" => "value", ..}, %{"id-2" => {"name" => "value", ..}}, ..}`
    |> Map.new()
  end

  defp remove_non_displayable_filesets(resources) do
    resources
    |> Enum.reject(fn r -> removable_resource?(r) end)
  end

  defp removable_resource?(%__MODULE__{metadata: %{"file_metadata" => file_metadata}}) do
    # Dig through file metadata and determine if FileSet is an image
    image? = Enum.find(file_metadata, false, fn fm -> is_image_file?(fm) end)

    if image? do
      false
    else
      true
    end
  end

  defp removable_resource?(_), do: false

  defp is_image_file?(%{"mime_type" => [mime_type]}) do
    String.contains?(mime_type, "image")
  end

  # Extract an id string from a value map.
  # Exclude values that have more than one key. These are field like
  # pending_upload which should not be extracted a related resources.
  defp extract_ids_from_value(value = %{"id" => id}) when map_size(value) == 1, do: id

  defp extract_ids_from_value(_), do: nil

  @spec extract_parent(resource :: %__MODULE__{}) :: related_resource_map()
  defp extract_parent(resource = %{:metadata => %{"cached_parent_id" => _cached_parent_id}}) do
    # turn it into a map of id => FiggyResource
    IndexingPipeline.get_figgy_parents(resource.id)
    |> Enum.map(fn m -> {m.id, to_map(m)} end)
    |> Map.new()
  end

  # there isn't a parent
  defp extract_parent(resource) do
    %{}
  end

  @spec parent_state(related_resource_map()) :: String.t()
  def parent_state(related_parent_map) when map_size(related_parent_map) > 0 do
    parent = Map.to_list(related_parent_map) |> hd |> elem(1)
    parent |> get_in([:metadata, "state"])
  end

  def parent_state(_), do: nil

  # Determine if a resource has no related member FileSets
  @spec to_map(%__MODULE__{}, related_resource_map()) :: map()
  defp resource_empty?(%__MODULE__{metadata: %{"member_ids" => member_ids}}, related_resources) do
    member_ids_set =
      member_ids
      |> Enum.map(&extract_ids_from_value/1)
      |> MapSet.new()

    related_ids_set =
      related_resources
      |> Map.keys()
      |> MapSet.new()

    # If the set of related ids doesn't contain any of the member ids,
    # then the resource is considered empty
    MapSet.disjoint?(member_ids_set, related_ids_set)
  end

  defp resource_empty?(_, _), do: true

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

  defp to_map(resource = %__MODULE__{}) do
    resource
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end

  @spec to_map(resource :: %__MODULE__{}, boolean()) :: map()
  defp to_map(resource = %__MODULE__{}, delete: true) do
    %{
      id: resource.id,
      internal_resource: resource.internal_resource,
      lock_version: resource.lock_version,
      created_at: resource.created_at,
      updated_at: resource.updated_at,
      metadata: %{"deleted" => true}
    }
  end
end
