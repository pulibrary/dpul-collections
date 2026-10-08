defmodule DpulCollections.IndexingPipeline.Figgy.Resource do
  @moduledoc """
  Schema for a resource in the Figgy database
  """
  use Ecto.Schema
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry
  @derive {JSON.Encoder, except: [:__meta__]}

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
    field :member_of_collection_ids, {:array, :map}, virtual: true
    field :metadata_resource_id, {:array, :map}, virtual: true
    field :metadata_resource_type, {:array, :string}, virtual: true
  end

  @type related_data() :: %{optional(field_name :: String.t()) => related_resource_map()}
  @type related_resource_map() :: %{
          optional(resource_id :: String.t()) => resource_struct :: map()
        }

  def populate_virtual(
        resource = %__MODULE__{
          metadata:
            metadata = %{
              "state" => state,
              "visibility" => visibility
            }
        }
      ) do
    %{
      resource
      | state: state,
        visibility: visibility,
        member_of_collection_ids: metadata["member_of_collection_ids"] || [],
        metadata_resource_id: metadata["resource_id"],
        metadata_resource_type: metadata["resource_type"]
    }
  end

  def populate_virtual(resource), do: resource

  @spec to_combined(%__MODULE__{}) :: %Figgy.CombinedFiggyResource{}
  def to_combined(%Figgy.Resource{id: id, metadata: nil}) do
    IndexingPipeline.get_figgy_resource!(id)
    |> to_combined()
  end

  def to_combined(resource = %Figgy.Resource{metadata: %{"member_ids" => member_ids}}) do
    related_data = extract_related_data(resource)

    related_data_markers =
      (Map.values(related_data["ancestors"]) ++ Map.values(related_data["collections"]) ++ Map.values(related_data["resources"]))
      |> List.flatten()
      |> Enum.map(&CacheEntryMarker.from/1)

    all_markers =
      [CacheEntryMarker.from(resource) | related_data_markers]
      |> Enum.sort(CacheEntryMarker)

    related_ids = Enum.map(related_data_markers, &Map.get(&1, :id))

    flattened_member_ids =
      member_ids |> Enum.map(&DpulCollections.Utilities.extract_ids_from_value/1) |> MapSet.new()

    %Figgy.CombinedFiggyResource{
      resource: resource,
      related_data: related_data,
      related_ids: related_ids,
      # all member ids that are getting added to dc
      persisted_member_ids:
        MapSet.intersection(flattened_member_ids, MapSet.new(related_ids)) |> MapSet.to_list(),
      latest_updated_marker: Enum.at(all_markers, -1)
    }
  end

  def to_combined(resource = %Figgy.Resource{internal_resource: "Collection"}) do
    %Figgy.CombinedFiggyResource{
      resource: resource,
      related_data: %{},
      related_ids: [],
      latest_updated_marker: CacheEntryMarker.from(resource)
    }
  end

  defp extract_related_data(resource) do
    related = fetch_related(resource)
    ancestors = extract_ancestors(resource)
    # Projects are treated like collections.
    projects = extract_projects(ancestors)

    %{
      "ancestors" => extract_ancestors(resource),
      "resources" => related,
      "collections" => Map.merge(extract_collections(resource), projects),
      "thumbnail" => get_thumbnail(resource, related),
      "member_thumbnails_subset" =>
        get_member_thumbnails_subset(resource, related, resource.metadata["member_ids"])
    }
  end

  # Pull just the projects from the ancestors map.
  defp extract_projects(ancestors) do
    ancestors
    |> Enum.filter(fn {_id, ancestor} -> ancestor.internal_resource == "EphemeraProject" end)
    |> Map.new()
  end

  @indexable_resource_types ResourceTypeRegistry.indexable_types()
  #
  # set default argument
  defp get_member_thumbnails_subset(resource, related, member_ids, member_thumbnails \\ [])

  # The first time we call this it will have the id map
  # filter out anything that's not a resource
  defp get_member_thumbnails_subset(
         resource = %Figgy.Resource{internal_resource: internal_resource},
         related,
         member_ids = [member_id_head | _],
         member_thumbnails
       )
       when is_map(member_id_head) and internal_resource in @indexable_resource_types do
    member_ids = member_ids |> Enum.map(&DpulCollections.Utilities.extract_ids_from_value/1)
    get_member_thumbnails(resource, related, member_ids, member_thumbnails)
  end

  defp get_member_thumbnails_subset(_resource, _related, _member_ids, _member_thumbnails), do: []

  # done condition
  defp get_member_thumbnails(_, _, [], member_thumbnails) do
    Enum.reverse(member_thumbnails)
  end

  # recurse condition
  defp get_member_thumbnails(
         resource,
         related,
         member_ids,
         member_thumbnails
       ) do
    # we only extract enough for the search results page
    if length(member_thumbnails) < 12 do
      # add one thumbnail to member_thumbnails, remove one from member_ids,
      # recurse
      [next_member_id | member_ids] = member_ids

      member_thumbnails = [
        get_member_thumbnail(related[next_member_id]) | member_thumbnails
      ]

      get_member_thumbnails(resource, related, member_ids, member_thumbnails)
    else
      Enum.reverse(member_thumbnails)
    end
  end

  defp get_member_thumbnail(member = %Figgy.Resource{internal_resource: "ScannedResource"}) do
    get_thumbnail(member, fetch_related(member))
  end

  defp get_member_thumbnail(member = %Figgy.Resource{internal_resource: "FileSet"}) do
    member
  end

  defp get_member_thumbnail(_), do: nil

  # if thumbnail is set, use it
  defp get_thumbnail(
         %Figgy.Resource{
           metadata: %{"member_ids" => member_ids, "thumbnail_id" => [thumbnail_id | _]}
         },
         related
       ) do
    first_valid_thumbnail(related, [thumbnail_id | member_ids])
  end

  # otherwise, take first member
  defp get_thumbnail(
         %Figgy.Resource{metadata: %{"member_ids" => member_ids}},
         related
       )
       when length(member_ids) > 0 do
    first_valid_thumbnail(related, member_ids)
  end

  # recurse if needed
  defp first_valid_thumbnail(related, id_priority_list) do
    # Convert all IDs to just the strings.
    with id_priority_list <- Enum.map(id_priority_list, &Map.get(&1, "id")),
         # Find the first ID that's in related.
         thumbnail_id <- Enum.find(id_priority_list, &Map.get(related, &1)),
         thumbnail = related[thumbnail_id] do
      case thumbnail do
        %{internal_resource: "FileSet"} ->
          thumbnail

        nil ->
          nil

        _ ->
          get_thumbnail(thumbnail, fetch_related(thumbnail))
      end
    end
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
  #       "label" => ["a genre"]  # Note: Figgy uses "genre", displayed as "Format" in DPUL Collections
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
  defp fetch_related(%Figgy.Resource{internal_resource: "EphemeraProject"}) do
    %{}
  end

  @spec fetch_related(%__MODULE__{}) :: related_data()
  defp fetch_related(resource = %Figgy.Resource{metadata: _metadata}) do
    resource
    |> related_list()
    # Map the returned Figgy.Resources into tuples of this form:
    # `{resource_id, %Figgy.Resource{}}`
    |> Enum.map(fn m -> {m.id, m} end)
    # Convert the list of tuples into a map with the form:
    # `%{"id-1" => %Figgy.Resource{ "name" => "value", ..}, %{"id-2" => %Figgy.Resource{"name" => "value", ..}}, ..}`
    |> Map.new()
  end

  defp related_list(%Figgy.Resource{metadata: metadata}) do
    metadata
    # Get the metadata property names
    |> Map.keys()
    # Filter out parent id as it's fetched in ancestors
    |> Enum.filter(fn key -> key != "cached_parent_id" end)
    # Map the values of each property into a list
    |> Enum.map(fn key -> metadata[key] end)
    # Flatten nested lists into a single list
    |> List.flatten()
    # If the value has the form `%{"id" => id}`, then extract the id string from map
    |> Enum.map(&DpulCollections.Utilities.extract_ids_from_value/1)
    # Remove nil and empty string values
    |> Enum.filter(fn id -> !is_nil(id) and id != "" end)
    # Query figgy using the resulting list of ids
    |> IndexingPipeline.get_figgy_resources()
    |> remove_non_indexable_children()
    # Get child resources recursively if we want them.
    |> Enum.map(&fetch_deep/1)
    |> List.flatten()
  end

  # Grab vocabularies if it's an EphemeraTerm
  defp fetch_deep(
         resource = %Figgy.Resource{
           internal_resource: "EphemeraTerm",
           metadata: %{"member_of_vocabulary_id" => _id}
         }
       ) do
    [resource | related_list(resource)]
  end

  defp fetch_deep(resource), do: resource

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

  @spec extract_collections(related_resource_map(), resource :: %__MODULE__{}) ::
          related_resource_map()
  defp extract_collections(resource_map \\ %{}, resource)

  defp extract_collections(
         resource_map,
         %{:metadata => %{"member_of_collection_ids" => member_of_collection_ids}}
       ) do
    collections =
      member_of_collection_ids
      |> Enum.map(&DpulCollections.Utilities.extract_ids_from_value/1)
      |> IndexingPipeline.get_figgy_resources()

    Enum.reduce(collections, resource_map, fn col, acc ->
      Map.put(acc, col.id, col)
    end)
  end

  defp extract_collections(resource_map, _resource), do: resource_map

  defp remove_non_indexable_children(resources) do
    resources
    |> Enum.reject(fn r -> removable_resource?(r) end)
  end

  # Allow MVWs
  defp removable_resource?(%Figgy.Resource{internal_resource: "ScannedResource"}) do
    false
  end

  # Only keep image file sets
  defp removable_resource?(%Figgy.Resource{metadata: %{"file_metadata" => file_metadata}}) do
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
