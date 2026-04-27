defmodule DpulCollections.IndexingPipeline.Figgy.Resource.Processor do
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  # Classification requires all figgy resources to have the virtual attributes
  # set. Resources pulled by the hydrator via `get_figgy_resources_since!` have
  # them, but related records fetched via `get_figgy_resource!` do not, so add
  # them first then recurse.
  @type process_return() ::
          {:update | :delete | :skip,
           [String]
           | %Figgy.Resource{}
           | %Figgy.DeletionRecord{}
           | %Figgy.CombinedFiggyResource{}}
  @spec process(resource :: %Figgy.Resource{}, cache_version :: integer) :: process_return()
  def process(
        resource = %Figgy.Resource{metadata: %{"visibility" => _visibility}, visibility: nil},
        cache_version
      ) do
    process(Figgy.Resource.populate_virtual(resource), cache_version)
  end

  @indexable_resource_types ResourceTypeRegistry.indexable_types()
  @related_record_types ResourceTypeRegistry.related_record_types()
  def process(resource, cache_version) do
    # Determine early on if we're deleting, skipping, or updating.
    with {:ok, classified_resources} <- initial_classification([resource], cache_version),
         # Add extra data
         {:ok, enriched_resources} <- enrich(classified_resources, cache_version),
         # Determine if after enrichment we should continue updating, delete, or skip.
         {:ok, final_resources} <- post_classification(enriched_resources, cache_version),
         {:ok, persisted_resources} <- persist(final_resources, cache_version) do
      {:ok, persisted_resources}
    end

    # resource
    # |> initial_classification(cache_version)
    # |> enrich(cache_version)
    # |> post_classification(cache_version)
  end

  @spec initial_classification(resource :: %Figgy.Resource{}, cache_version :: integer) ::
          process_return()
  def initial_classification(resources, cache_version) when is_list(resources) do
    classifications =
      resources
      |> Enum.map(&initial_classification(&1, cache_version))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, resources} -> resources end)
      |> List.flatten()

    case classifications do
      [] -> {:error, nil}
      _ -> {:ok, classifications}
    end
  end

  def initial_classification(resource = %Figgy.Resource{id: id}, cache_version) do
    case resource do
      # Process open/complete indexable resources (EphemeraFolder, ScannedResource).
      # ScannedResources are filtered by collection membership.
      %{internal_resource: internal_resource, state: ["complete"], visibility: ["open"]}
      when internal_resource in @indexable_resource_types ->
        classify_open_resource(resource)

      # Collections need to both update
      %{internal_resource: "Collection"} ->
        if ResourceTypeRegistry.allowed_collection?(id) do
          {:ok, {:update, resource}}
        else
          {:error, :skip}
        end

      # Projects need to both update and get related.
      %{internal_resource: "EphemeraProject"} ->
        {:ok, [{:update, resource}, {:update_related, resource}]}

      # Process things that could be related records
      %{internal_resource: internal_resource} when internal_resource in @related_record_types ->
        {:ok, {:update_related, resource}}

      # Delete indexable resources that are already cached but no longer
      # eligible (e.g. no longer open/complete), otherwise skip them.
      %{internal_resource: internal_resource} when internal_resource in @indexable_resource_types ->
        existing_resource = IndexingPipeline.get_figgy_combined_resource!(id, cache_version)

        if existing_resource do
          {:ok, {:delete, resource}}
        else
          {:error, :skip}
        end

      # Delete resources with DeletionMarkers if they're cached, otherwise skip.
      %{
        internal_resource: "DeletionMarker",
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: [resource_type]
      }
      when resource_type in @indexable_resource_types ->
        existing_resource =
          IndexingPipeline.get_figgy_combined_resource!(resource_id, cache_version)

        if existing_resource do
          {:ok, {:delete, resource}}
        else
          {:error, :skip}
        end

      _ ->
        {:error, :skip}
    end
  end

  defp classify_open_resource(%{internal_resource: "ScannedResource"} = resource) do
    if member_of_allowed_collection?(resource) do
      {:ok, {:update, resource}}
    else
      {:error, {:skip, resource}}
    end
  end

  defp classify_open_resource(resource), do: {:ok, {:update, resource}}

  defp member_of_allowed_collection?(resource) do
    collection_ids = Enum.map(resource.member_of_collection_ids, & &1["id"])
    Enum.any?(collection_ids, &ResourceTypeRegistry.allowed_collection?/1)
  end

  # If we got a list of them, enrich each one.
  def enrich(process_list = [{_, _} | _], cache_version) do
    classifications =
      process_list
      |> Enum.map(&enrich(&1, cache_version))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, resources} -> resources end)
      |> List.flatten()

    case classifications do
      [] -> {:error, nil}
      _ -> {:ok, classifications}
    end
  end

  # If it's a related resource, get ids of all records dependent on this one
  # one.
  @spec process(process_return(), cache_version :: integer) :: process_return()
  def enrich(
        {:update_related,
         %Figgy.Resource{id: id, updated_at: timestamp, internal_resource: internal_resource}},
        cache_version
      )
      when internal_resource in @related_record_types do
    related_record_ids =
      IndexingPipeline.get_related_figgy_combined_resource_record_ids!(
        id,
        timestamp,
        cache_version
      )

    {:ok,
     {
       :update_related,
       related_record_ids
     }}
  end

  # We don't have the full resource yet, fetch it and re-enrich.
  def enrich({:update, %Figgy.Resource{id: id, metadata: nil}}, cache_version) do
    enrich({:update, IndexingPipeline.get_figgy_resource!(id)}, cache_version)
  end

  # Resources we're updating need to become combined figgy resources.
  def enrich({:update, resource}, _cache_version) do
    combined_resource = Figgy.Resource.to_combined(resource)
    {:ok, {:update, combined_resource}}
  end

  # Deletion markers need to become DeletionRecords
  def enrich(
        {:delete,
         resource = %Figgy.Resource{
           internal_resource: "DeletionMarker",
           metadata_resource_id: [%{"id" => resource_id}],
           metadata_resource_type: [resource_type]
         }},
        _cache_version
      ) do
    {:ok,
     {:delete,
      %Figgy.DeletionRecord{
        marker: CacheEntryMarker.from(resource),
        internal_resource: resource_type,
        id: resource_id
      }}}
  end

  # Deleted resources need to become DeletionRecords
  def enrich({:delete, resource = %Figgy.Resource{}}, _cache_version) do
    {:ok,
     {:delete,
      %Figgy.DeletionRecord{
        marker: CacheEntryMarker.from(resource),
        internal_resource: resource.internal_resource,
        id: resource.id
      }}}
  end

  def enrich(resource_and_classification, _cache_version), do: {:ok, resource_and_classification}

  def post_classification(process_list = [{_, _} | _], cache_version) do
    classifications =
      process_list
      |> Enum.map(&post_classification(&1, cache_version))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, resources} -> resources end)
      |> List.flatten()

    case classifications do
      [] -> {:error, nil}
      _ -> {:ok, classifications}
    end
  end

  # Published ephemera projects go through.
  def post_classification(
        {:update,
         resource = %Figgy.CombinedFiggyResource{
           resource: %{
             id: id,
             internal_resource: "EphemeraProject",
             metadata: metadata
           },
           latest_updated_marker: marker
         }},
        cache_version
      ) do
    case metadata do
      %{"publish" => ["1"]} ->
        {:ok, {:update, resource}}

      _ ->
        # Delete if we've seen the project before.
        existing_resource = IndexingPipeline.get_figgy_combined_resource!(id, cache_version)

        if existing_resource do
          {:ok,
           {:delete,
            %Figgy.DeletionRecord{
              marker: marker,
              internal_resource: resource.resource.internal_resource,
              id: id
            }}}
        else
          {:error, :skip}
        end
    end
  end

  # Collections go through.
  def post_classification(
        {:update,
         resource = %Figgy.CombinedFiggyResource{
           resource: %{
             internal_resource: "Collection"
           }
         }},
        _cache_version
      ) do
    {:ok, {:update, resource}}
  end

  # Every other ephemera project does not.
  #

  # Delete things which have no persisted members.
  @spec post_classification(process_return(), cache_version :: integer) ::
          process_return()
  def post_classification(
        {:update,
         %Figgy.CombinedFiggyResource{
           resource: resource,
           persisted_member_ids: [],
           latest_updated_marker: marker
         }},
        _cache_version
      ) do
    {:ok,
     {:delete,
      %Figgy.DeletionRecord{
        marker: marker,
        internal_resource: resource.internal_resource,
        id: resource.id
      }}}
  end

  # A related resource returned an empty list, skip.
  def post_classification({:update_related, []}, _cache_version) do
    {:error, :skip}
  end

  def post_classification(resource_and_classification, _cache_version),
    do: {:ok, resource_and_classification}

  # If we're passed a bunch of process_returns, iterate.
  def persist(action_list = [{_, _} | _], cache_version) do
    classifications =
      action_list
      |> Enum.map(&persist(&1, cache_version))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, resources} -> resources end)
      |> List.flatten()

    case classifications do
      [] -> {:error, nil}
      _ -> {:ok, nil}
    end
  end

  # If we're passed several IDs, process them in order and persist.
  @spec persist(process_return(), cache_version :: integer) ::
          {:ok, %Figgy.CombinedResource{}}
  def persist(update = {:update_related, id_list = [id | _]}, cache_version)
      when is_binary(id) do
    # Do one at a time to prevent memory ballooning.
    id_list
    |> Enum.each(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> process(cache_version)
      |> persist(cache_version)
    end)

    {:ok, update}
  end

  def persist(process_return = {action, _resource}, cache_version)
      when action in [:delete, :update] do
    # Maybe move to CombinedResource.from?
    attributes = figgy_combined_resource_attributes(process_return, cache_version)
    {:ok, _response} = IndexingPipeline.write_figgy_combined_resource(attributes)
  end

  def persist({:skip, _}, _cache_version), do: {:error, nil}

  @spec figgy_combined_resource_attributes(
          %Figgy.DeletionRecord{} | %Figgy.CombinedFiggyResource{},
          cache_version :: integer
        ) :: %{
          :handled_data => map(),
          :related_data => Figgy.CombinedFiggyResource.related_data()
        }
  def figgy_combined_resource_attributes({_action, resource}, cache_version),
    do: figgy_combined_resource_attributes(resource, cache_version)

  # store in HydrationCache:
  # - cache_version (this only changes manually, we have to hold onto it as state)
  # - record_id (varchar) - the figgy UUID
  # - data (blob) - this is the record
  # - related_data (blob) - map of related data
  # - related_ids (array<string>) - array of IDs that are contained in
  #   related_data
  # - source_cache_order (datetime) - most recent figgy or related resource updated_at
  # - source_cache_order_record_id (varchar) - record id of the source_cache_order value
  def figgy_combined_resource_attributes(
        %Figgy.DeletionRecord{
          marker: marker,
          id: id,
          internal_resource: internal_resource
        },
        cache_version
      ) do
    %{
      cache_version: cache_version,
      record_id: id,
      related_ids: [],
      source_cache_order: marker.timestamp,
      source_cache_order_record_id: marker.id,
      resource: %{internal_resource: internal_resource, id: id, metadata: %{"deleted" => true}}
    }
  end

  def figgy_combined_resource_attributes(
        combined_resource = %Figgy.CombinedFiggyResource{resource: resource},
        cache_version
      ) do
    %{
      cache_version: cache_version,
      record_id: resource.id,
      resource: resource,
      related_data: combined_resource.related_data,
      related_ids: combined_resource.related_ids,
      source_cache_order: combined_resource.latest_updated_marker.timestamp,
      source_cache_order_record_id: combined_resource.latest_updated_marker.id
    }
  end
end
