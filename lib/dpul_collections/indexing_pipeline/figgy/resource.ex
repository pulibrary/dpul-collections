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

  # def to_combined_figgy_resource(resource) do
  #   hydration_cache_attrs = to_hydration_cache_attrs(resource)
  #   # data hydration cache entry needs...
  #   %{
  #     # handled_data is either a deletion map or the resource converted to a
  #     # map, with special handling for DeletionMarkers.
  #     handled_data: handled_data,
  #     # A list of all the related resources.
  #     related_data: related_data,
  #     # All the related IDs
  #     related_ids: related_ids(related_data),
  #     # The latest timestamp used to build this resource.
  #     source_cache_order: source_cache_order,
  #     source_cache_order_record_id: source_cache_order_record_id
  #   }
  # end

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
    related_data = extract_related_data(resource)

    handled_data =
      if resource_empty?(resource, related_data) do
        resource |> to_map(delete: true)
      else
        resource |> to_map
      end

    {source_cache_order, source_cache_order_record_id} =
      calculate_source_cache_order(resource, related_data)

    %{
      handled_data: handled_data,
      related_data: related_data,
      related_ids: related_ids(related_data),
      source_cache_order: source_cache_order,
      source_cache_order_record_id: source_cache_order_record_id
    }
  end

  def calculate_source_cache_order(resource, related_data) do
    primary_resource = [{resource.updated_at, resource.id}]

    related_resources =
      (related_data["resources"] || %{})
      |> Map.keys()
      |> Enum.map(fn key -> related_data["resources"][key] end)
      |> Enum.map(fn r -> {r[:updated_at], r[:id]} end)

    ancestors =
      (related_data["ancestors"] || %{})
      |> Map.keys()
      |> Enum.map(fn key -> related_data["ancestors"][key] end)
      |> Enum.map(fn r -> {r[:updated_at], r[:id]} end)

    # Combine and sort by date
    # Return the most recent date, id tuple
    (primary_resource ++ related_resources ++ ancestors)
    |> Enum.sort_by(fn {date, _} -> date end, {:desc, DateTime})
    |> Enum.at(0)
  end

  def extract_related_data(resource) do
    %{
      "ancestors" => extract_ancestors(resource),
      "resources" => fetch_related(resource)
    }
  end

  # Finds all metadata properties which contain references to related resources
  # (those with the form `[%{"id" => id}]` and then fetches those resources from Figgy
  # in a single query.
  #
  ## Example
  #
  # ```
  # r = %Figgy.Resource{
  #       id: "097263fb-5beb-407b-ab36-b468e0489792",
  #       internal_resource: "EphemeraFolder",
  #       metadata: %{
  #         "genre": [%{"id" => "668a21d7-750d-477d-b569-54ad511f13d7"}],
  #         "member_ids": [%{"id" => "557cc7c1-9852-471b-ae4d-f1c14be3890b"}]
  #       }
  #     }
  #
  # fetch_related(r)
  #
  # Returns:
  # %{
  #   "668a21d7-750d-477d-b569-54ad511f13d7" => %{
  #     "id" => "668a21d7-750d-477d-b569-54ad511f13d7",
  #     "internal_resource" => "EphemeraTerm",
  #     "metadata" => %{
  #       "label" => ["a genre"]
  #     }
  #   },
  #   "557cc7c1-9852-471b-ae4d-f1c14be3890b" => %{
  #     "id" => "557cc7c1-9852-471b-ae4d-f1c14be3890b",
  #     "internal_resource: "FileSet",
  #     "metadata" => %{
  #       "file_metadata" => [
  #         %{
  #           "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4017"},
  #           "internal_resource" => "FileMetadata",
  #           "mime_type" => ["image/tiff"],
  #           "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
  #         }
  #       ]
  #     }
  #   }
  # ```
  @spec fetch_related(%__MODULE__{}) :: related_data()
  defp fetch_related(%__MODULE__{metadata: metadata}) do
    metadata
    # Get the metadata property names
    |> Map.keys()
    # Filter out parent id as it's fetched in ancestors
    |> Enum.filter(fn key -> key != "cached_parent_id" end)
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

  # Concat ids for all ancestors and related resources into a single list
  @spec related_ids(related_data()) :: list(String.t())
  defp related_ids(related_data) do
    ancestor_ids = (related_data["ancestors"] || %{}) |> Map.keys()
    resource_ids = (related_data["resources"] || %{}) |> Map.keys()
    ancestor_ids ++ resource_ids
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

  @spec extract_ancestors(related_resource_map(), resource :: %__MODULE__{}) ::
          related_resource_map()
  defp extract_ancestors(resource_map \\ %{}, resource)

  defp extract_ancestors(
         resource_map,
         resource = %{:metadata => %{"cached_parent_id" => _cached_parent_id}}
       ) do
    parent = IndexingPipeline.get_figgy_parents(resource.id) |> Enum.at(0)

    cond do
      is_nil(parent) ->
        resource_map

      true ->
        resource_map
        |> Map.put(parent.id, to_map(parent))
        |> extract_ancestors(parent)
    end
  end

  defp extract_ancestors(resource_map, _resource), do: resource_map

  # Determine if a resource has no related member FileSets
  @spec to_map(%__MODULE__{}, related_data()) :: map()
  defp resource_empty?(%__MODULE__{metadata: %{"member_ids" => member_ids}}, %{
         "resources" => related_resources
       }) do
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
