defmodule DpulCollections.IndexingPipeline.Figgy.Resource do
  @moduledoc """
  Schema for a resource in the Figgy database
  """
  use Ecto.Schema
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
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

  # @spec to_hydration_cache_attrs(%__MODULE__{}) :: %{
  #         handled_data: map(),
  #         related_data: Figgy.CombinedFiggyResource.related_data()
  #       }
  # # TODO: Remove this
  # def to_hydration_cache_attrs(resource = %__MODULE__{}) do
  #   resource
  #   |> HydrationConsumer.process(1)
  #   |> elem(1)
  #   |> HydrationConsumer.hydration_cache_attributes(1)
  # end

  @spec to_combined(%__MODULE__{}) :: %Figgy.CombinedFiggyResource{}
  def to_combined(resource = %Figgy.Resource{metadata: %{"member_ids" => member_ids}}) do
    related_data = extract_related_data(resource)

    related_data_markers =
      (Map.values(related_data["ancestors"]) ++ Map.values(related_data["resources"]))
      |> List.flatten()
      |> Enum.map(&CacheEntryMarker.from/1)

    all_markers =
      [CacheEntryMarker.from(resource) | related_data_markers]
      |> Enum.sort(CacheEntryMarker)

    related_ids = Enum.map(related_data_markers, &Map.get(&1, :id))
    flattened_member_ids = member_ids |> Enum.map(&extract_ids_from_value/1) |> MapSet.new()

    %Figgy.CombinedFiggyResource{
      resource: resource,
      related_data: related_data,
      related_ids: related_ids,
      persisted_member_ids:
        MapSet.intersection(flattened_member_ids, MapSet.new(related_ids)) |> MapSet.to_list(),
      latest_updated_marker: Enum.at(all_markers, -1)
    }
  end

  defp extract_related_data(resource) do
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
  defp fetch_related(%Figgy.Resource{metadata: metadata}) do
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
    |> Enum.map(fn m -> {m.id, m} end)
    # Convert the list of tuples into a map with the form:
    # `%{"id-1" => %{ "name" => "value", ..}, %{"id-2" => {"name" => "value", ..}}, ..}`
    |> Map.new()
  end

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
        |> Map.put(parent.id, parent)
        |> extract_ancestors(parent)
    end
  end

  defp extract_ancestors(resource_map, _resource), do: resource_map

  # Extract an id string from a value map.
  # Exclude values that have more than one key. These are field like
  # pending_upload which should not be extracted a related resources.
  defp extract_ids_from_value(value = %{"id" => id}) when map_size(value) == 1, do: id

  defp extract_ids_from_value(_), do: nil

  defp remove_non_displayable_filesets(resources) do
    resources
    |> Enum.reject(fn r -> removable_resource?(r) end)
  end

  defp removable_resource?(%Figgy.Resource{metadata: %{"file_metadata" => file_metadata}}) do
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
end
