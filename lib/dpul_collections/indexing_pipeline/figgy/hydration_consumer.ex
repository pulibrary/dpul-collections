defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
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
    |> to_hydration_cache_entries(cache_version)
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
  def to_hydration_cache_entries(%{internal_resource: internal_resource}, _cache_version)
      when internal_resource not in @processed_types do
    []
  end

  # DeletionMarkers delete any records it's pointing to it if they've been
  # processed before.
  def to_hydration_cache_entries(resource = %{internal_resource: "DeletionMarker"}, cache_version) do
    case resource do
      %{
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: [resource_type]
      }
      when resource_type in @indexable_resource_types ->
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource_id, cache_version)

        if existing_resource do
          [HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)]
        else
          []
        end

      _ ->
        []
    end
  end

  # Collections only update if they're allowed.
  def to_hydration_cache_entries(
        resource = %{internal_resource: "Collection", id: id},
        cache_version
      ) do
    if ResourceTypeRegistry.allowed_collection?(id) do
      [HydrationCacheEntry.from(resource, cache_version)]
    else
      []
    end
  end

  # Ingest EphemeraFolders
  def to_hydration_cache_entries(resource = %{internal_resource: "EphemeraFolder"}, cache_version) do
    case resource do
      # Process open/complete
      %{state: ["complete"], visibility: ["open"]} ->
        combined_figgy_resource = Figgy.Resource.to_combined(resource)
        # Delete it it has no member_ids.
        if combined_figgy_resource.persisted_member_ids == [] do
          # NOTE: This is actually a bug, we shouldn't be creating a deletion
          # record if we've never seen it, probably, but we have a test in
          # FullIntegrationTest checking that it exists.
          [HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)]
        else
          [HydrationCacheEntry.from(combined_figgy_resource, cache_version)]
        end

      _ ->
        # Delete it if we've seen it before.
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource.id, cache_version)

        if existing_resource do
          [HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)]
        else
          []
        end
    end
  end

  # Ingest ScannedResources
  def to_hydration_cache_entries(
        resource = %{internal_resource: "ScannedResource"},
        cache_version
      ) do
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

            [HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)]
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
          [HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)]
        else
          []
        end
    end
  end

  def to_hydration_cache_entries(
        resource = %{internal_resource: "EphemeraProject", id: id},
        cache_version
      ) do
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
            [
              HydrationCacheEntry.from(
                Figgy.DeletionRecord.from(combined_resource),
                cache_version
              )
            ]
          else
            []
          end
      end,
      related_records(resource, cache_version)
    )
  end

  def to_hydration_cache_entries(
        resource = %{internal_resource: internal_resource},
        cache_version
      )
      when internal_resource in @related_record_types do
    related_records(resource, cache_version)
  end

  defp member_of_allowed_collection?(resource) do
    collection_ids = Enum.map(resource.member_of_collection_ids, & &1["id"])
    Enum.any?(collection_ids, &ResourceTypeRegistry.allowed_collection?/1)
  end

  def related_records(%{updated_at: timestamp, id: id}, cache_version) do
    IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)
    |> Stream.flat_map(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> to_hydration_cache_entries(cache_version)
    end)
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
