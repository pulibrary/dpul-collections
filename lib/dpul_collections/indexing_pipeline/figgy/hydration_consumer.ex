defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  use Broadway

  @type start_opts ::
          {:cache_version, Integer}
          | {:producer_module, Module}
          | {:producer_options, any()}
          | {:batch_size, Integer}
  @spec start_link([start_opts()]) :: Broadway.on_start()

  def start_link(options \\ []) do
    # Need to set cache version here so that the correct cache version is set and to
    # allow very different producer options for the Mock Producer.
    cache_version = options[:cache_version] || 0

    default = [
      cache_version: cache_version,
      producer_module: DatabaseProducer,
      producer_options: {Figgy.HydrationProducerSource, cache_version},
      batch_size: 10
    ]

    options = Keyword.merge(default, options)

    Broadway.start_link(__MODULE__,
      name: String.to_atom("#{__MODULE__}_#{cache_version}"),
      producer: [
        module: {options[:producer_module], options[:producer_options]}
      ],
      processors: [
        default: [concurrency: System.schedulers_online() * 2]
      ],
      batchers: [
        default: [concurrency: 5, batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version], type: :figgy_hydrator}
    )
  end

  @impl Broadway
  # pass through messages and write to cache in batcher to avoid race condition
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: resource = %Figgy.Resource{}
        },
        %{cache_version: cache_version}
      ) do
    resource
    |> process_and_persist(cache_version)

    message
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, _state) do
    messages
  end

  def process_and_persist(resource, cache_version) do
    # Take a resource, convert it into a stream of hydration_cache_entries, then
    # save them all.
    resource
    |> early_conversion(cache_version)
    # |> process(cache_version)
    # |> to_hydration_cache_entries(cache_version)
    |> save_all()
  end

  defp save_all(resources) do
    resources
    |> Enum.each(&IndexingPipeline.write_hydration_cache_entry/1)

    {:ok, nil}
  end

  @indexable_resource_types ResourceTypeRegistry.indexable_types()
  @related_record_types ResourceTypeRegistry.related_record_types()
  @processed_types ResourceTypeRegistry.processed_types()
  # Immediately skip anything not in processed_types.
  def early_conversion(%{internal_resource: internal_resource}, _cache_version)
      when internal_resource not in @processed_types do
    []
  end

  # DeletionMarkers delete any records it's pointing to it if they've been
  # processed before.
  def early_conversion(resource = %{internal_resource: "DeletionMarker"}, cache_version) do
    case resource do
      %{
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: [resource_type]
      }
      when resource_type in @indexable_resource_types ->
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource_id, cache_version)

        if existing_resource do
          deletion_record = %Figgy.DeletionRecord{
            marker: CacheEntryMarker.from(resource),
            internal_resource: resource_type,
            id: resource_id
          }

          [HydrationCacheEntry.from(deletion_record, cache_version)]
        else
          []
        end

      _ ->
        []
    end
  end

  # Collections only update if they're allowed.
  def early_conversion(resource = %{internal_resource: "Collection", id: id}, cache_version) do
    if ResourceTypeRegistry.allowed_collection?(id) do
      [HydrationCacheEntry.from(resource, cache_version)]
    else
      []
    end
  end

  # Ingest EphemeraFolders
  def early_conversion(resource = %{internal_resource: "EphemeraFolder"}, cache_version) do
    case resource do
      # Process open/complete
      %{state: ["complete"], visibility: ["open"]} ->
        combined_figgy_resource = Figgy.Resource.to_combined(resource)
        # Delete it it has no member_ids.
        if combined_figgy_resource.persisted_member_ids == [] do
          # NOTE: This is actually a bug, we shouldn't be creating a deletion
          # record if we've never seen it, probably, but we have a test in
          # FullIntegrationTest checking that it exists.
          deletion_record = %Figgy.DeletionRecord{
            marker: CacheEntryMarker.from(resource),
            internal_resource: resource.internal_resource,
            id: resource.id
          }

          [HydrationCacheEntry.from(deletion_record, cache_version)]
        else
          [HydrationCacheEntry.from(combined_figgy_resource, cache_version)]
        end

      _ ->
        # Delete it if we've seen it before.
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource.id, cache_version)

        if existing_resource do
          deletion_record = %Figgy.DeletionRecord{
            marker: CacheEntryMarker.from(resource),
            internal_resource: resource.internal_resource,
            id: resource.id
          }

          [HydrationCacheEntry.from(deletion_record, cache_version)]
        else
          []
        end
    end
  end

  # Ingest ScannedResources
  def early_conversion(resource = %{internal_resource: "ScannedResource"}, cache_version) do
    case resource do
      # Process open/complete
      %{state: ["complete"], visibility: ["open"], member_of_collection_ids: [_ | _]} ->
        if member_of_allowed_collection?(resource) do
          combined_figgy_resource = Figgy.Resource.to_combined(resource)
          # Delete it when it has no member_ids.
          if combined_figgy_resource.persisted_member_ids == [] do
            # NOTE: This is actually a bug, we shouldn't be creating a deletion
            # record if we've never seen it, probably, but we have a test in
            # FullIntegrationTest checking that it exists.
            deletion_record = %Figgy.DeletionRecord{
              marker: CacheEntryMarker.from(resource),
              internal_resource: resource.internal_resource,
              id: resource.id
            }

            [HydrationCacheEntry.from(deletion_record, cache_version)]
          else
            [HydrationCacheEntry.from(combined_figgy_resource, cache_version)]
          end
        else
          []
        end

      _ ->
        # Delete it if we've seen it before.
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource.id, cache_version)

        if existing_resource do
          deletion_record = %Figgy.DeletionRecord{
            marker: CacheEntryMarker.from(resource),
            internal_resource: resource.internal_resource,
            id: resource.id
          }

          [HydrationCacheEntry.from(deletion_record, cache_version)]
        else
          []
        end
    end
  end

  def early_conversion(resource = %{internal_resource: "EphemeraProject", id: id}, cache_version) do
    combined_resource = Figgy.Resource.to_combined(resource)

    Stream.concat(
      case combined_resource.resource.metadata do
        %{"publish" => ["1"]} ->
          # Save published EphemeraProjects, update related records
          [HydrationCacheEntry.from(combined_resource, cache_version)]

        _ ->
          # Delete if we've seen it before
          existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

          if existing_resource do
            deletion_record = %Figgy.DeletionRecord{
              marker: combined_resource.latest_updated_marker,
              internal_resource: "EphemeraProject",
              id: id
            }

            [HydrationCacheEntry.from(deletion_record, cache_version)]
          else
            []
          end
      end,
      related_records(resource, cache_version)
    )
  end

  def early_conversion(resource = %{internal_resource: internal_resource}, cache_version)
      when internal_resource in @related_record_types do
    related_records(resource, cache_version)
  end

  def early_conversion(resource, _cache_version) do
    resource
  end

  def related_records(%{updated_at: timestamp, id: id}, cache_version) do
    IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)
    |> Stream.flat_map(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> early_conversion(cache_version)
      |> process(cache_version)
      |> to_hydration_cache_entries(cache_version)
    end)
  end

  # Allow fall-through if early conversion solved it already.
  def process(cache_entry = %HydrationCacheEntry{}, _cache_version), do: cache_entry
  def process(cache_entries = [%HydrationCacheEntry{} | _], _cache_version), do: cache_entries
  def process(cache_entries = %Stream{}, _cache_version), do: cache_entries
  def process([], _cache_version), do: []

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

  def process(resource = %Figgy.Resource{}, cache_version) do
    resource
    # Determine early on if we're deleting, skipping, or updating.
    |> initial_classification(cache_version)
    # Add extra data
    |> enrich(cache_version)
    # Determine if after enrichment we should continue updating, delete, or skip.
    |> post_classification(cache_version)
  end

  def process(fallthrough, _cache_version), do: fallthrough

  @spec initial_classification(resource :: %Figgy.Resource{}, cache_version :: integer) ::
          process_return()
  def initial_classification(resource = %Figgy.Resource{id: id}, cache_version) do
    case resource do
      # Process open/complete indexable resources (EphemeraFolder, ScannedResource).
      # ScannedResources are filtered by collection membership.
      %{internal_resource: internal_resource, state: ["complete"], visibility: ["open"]}
      when internal_resource in @indexable_resource_types ->
        classify_open_resource(resource)

      # Projects need to both update and get related.
      %{internal_resource: "EphemeraProject"} ->
        [{:update, resource}, {:update_related, resource}]

      # Process things that could be related records
      %{internal_resource: internal_resource} when internal_resource in @related_record_types ->
        {:update_related, resource}

      # Delete indexable resources that are already cached but no longer
      # eligible (e.g. no longer open/complete), otherwise skip them.
      %{internal_resource: internal_resource} when internal_resource in @indexable_resource_types ->
        existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

        if existing_resource do
          {:delete, resource}
        else
          {:skip, resource}
        end

      # Delete resources with DeletionMarkers if they're cached, otherwise skip.
      %{
        internal_resource: "DeletionMarker",
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: [resource_type]
      }
      when resource_type in @indexable_resource_types ->
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource_id, cache_version)

        if existing_resource do
          {:delete, resource}
        else
          {:skip, resource}
        end

      _ ->
        {:skip, resource}
    end
  end

  defp classify_open_resource(%{internal_resource: "ScannedResource"} = resource) do
    if member_of_allowed_collection?(resource) do
      {:update, resource}
    else
      {:skip, resource}
    end
  end

  defp classify_open_resource(resource), do: {:update, resource}

  defp member_of_allowed_collection?(%{member_of_collection_ids: nil}), do: false

  defp member_of_allowed_collection?(resource) do
    collection_ids = Enum.map(resource.member_of_collection_ids, & &1["id"])
    Enum.any?(collection_ids, &ResourceTypeRegistry.allowed_collection?/1)
  end

  # If we got a list of them, enrich each one.
  def enrich(process_list = [{_, _} | _], cache_version) do
    process_list
    |> Enum.map(&enrich(&1, cache_version))
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
      IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)

    {
      :update_related,
      related_record_ids
    }
  end

  # We don't have the full resource yet, fetch it and re-enrich.
  def enrich({:update, %Figgy.Resource{id: id, metadata: nil}}, cache_version) do
    enrich({:update, IndexingPipeline.get_figgy_resource!(id)}, cache_version)
  end

  # Resources we're updating need to become combined figgy resources.
  def enrich({:update, resource}, _cache_version) do
    combined_resource = Figgy.Resource.to_combined(resource)
    {:update, combined_resource}
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
    {:delete,
     %Figgy.DeletionRecord{
       marker: CacheEntryMarker.from(resource),
       internal_resource: resource_type,
       id: resource_id
     }}
  end

  # Deleted resources need to become DeletionRecords
  def enrich({:delete, resource = %Figgy.Resource{}}, _cache_version) do
    {:delete,
     %Figgy.DeletionRecord{
       marker: CacheEntryMarker.from(resource),
       internal_resource: resource.internal_resource,
       id: resource.id
     }}
  end

  def enrich(resource_and_classification, _cache_version), do: resource_and_classification

  def post_classification(process_list = [{_, _} | _], cache_version) do
    process_list
    |> Enum.map(&post_classification(&1, cache_version))
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
        {:update, resource}

      _ ->
        # Delete if we've seen the project before.
        existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

        if existing_resource do
          {:delete,
           %Figgy.DeletionRecord{
             marker: marker,
             internal_resource: resource.resource.internal_resource,
             id: id
           }}
        else
          {:skip, resource}
        end
    end
  end

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
    {:delete,
     %Figgy.DeletionRecord{
       marker: marker,
       internal_resource: resource.internal_resource,
       id: resource.id
     }}
  end

  # A related resource returned an empty list, skip.
  def post_classification({:update_related, []}, _cache_version) do
    {:skip, []}
  end

  def post_classification(resource_and_classification, _cache_version),
    do: resource_and_classification

  # If there's a bunch of actions, only no-op if all of them are skips.
  def store_result(process_list = [{_, _} | _], message) do
    case Enum.filter(process_list, fn {action, _} -> action != :skip end) do
      [] -> Broadway.Message.put_batcher(message, :noop)
      _ -> message
    end
  end

  @spec store_result(process_return(), message :: Broadway.Message.t()) ::
          Broadway.Message.t()
  def store_result({:skip, _record}, message), do: Broadway.Message.put_batcher(message, :noop)

  def store_result(_, message),
    do: message

  # to_hydration_cache_entries converts a list of actions into a stream of
  # HydrationCacheEntries. We don't convert to a list so we don't store every
  # resource in memory to save them later.
  # If we're passed a bunch of process_returns, iterate.
  defp to_hydration_cache_entries(action_list = [{_, _} | _], cache_version) do
    action_list
    |> Stream.flat_map(&to_hydration_cache_entries(&1, cache_version))
  end

  # If we're passed several IDs, process them in order and persist.
  @spec to_hydration_cache_entries(process_return(), cache_version :: integer) ::
          [%Figgy.HydrationCacheEntry{}] | []
  defp to_hydration_cache_entries({:update_related, id_list = [id | _]}, cache_version)
       when is_binary(id) do
    # Do one at a time to prevent memory ballooning.
    id_list
    |> Stream.flat_map(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> process(cache_version)
      |> to_hydration_cache_entries(cache_version)
    end)
  end

  defp to_hydration_cache_entries({action, resource}, cache_version)
       when action in [:delete, :update] do
    # Maybe move to HydrationCacheEntry.from?
    [HydrationCacheEntry.from(resource, cache_version)]
  end

  defp to_hydration_cache_entries({:skip, _}, _cache_version), do: []

  # Fallthrough in case early_conversion handled it.
  defp to_hydration_cache_entries(other, _cache_version), do: other

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
