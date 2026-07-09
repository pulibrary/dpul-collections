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
    # Convert the resource to a cache entry and append any related records, then
    # save all of them together.
    all_resources =
      Stream.concat(
        [to_hydration_cache_entry(resource, cache_version)],
        related_records(resource, cache_version)
      )

    save_all(all_resources)
  end

  defp save_all(resources) do
    resources
    |> Stream.reject(&is_nil/1)
    |> Enum.each(&IndexingPipeline.write_hydration_cache_entry/1)

    {:ok, nil}
  end

  @indexable_resource_types ResourceTypeRegistry.indexable_types()
  @collection_types ResourceTypeRegistry.collection_types()
  @related_record_types ResourceTypeRegistry.related_record_types()
  @processed_types ResourceTypeRegistry.processed_types()

  # Immediately skip anything not in processed_types.
  def to_hydration_cache_entry(%{internal_resource: internal_resource}, _cache_version)
      when internal_resource not in @processed_types do
    nil
  end

  # DeletionMarkers delete any records it's pointing to if they've been
  # processed before.
  def to_hydration_cache_entry(resource = %{internal_resource: "DeletionMarker"}, cache_version) do
    case resource do
      %{
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: [resource_type]
      }
      when resource_type in @indexable_resource_types ->
        delete_if_seen(resource_id, resource, cache_version)

      _ ->
        nil
    end
  end

  # Ingest EphemeraFolders / ScannedResources
  def to_hydration_cache_entry(resource = %{internal_resource: internal_resource}, cache_version)
      when internal_resource in @indexable_resource_types do
    if process?(resource) do
      combined_figgy_resource = Figgy.Resource.to_combined(resource)

      if process?(combined_figgy_resource) do
        HydrationCacheEntry.from(combined_figgy_resource, cache_version)
      else
        # Delete if it has no member_ids.
        # NOTE: This is actually a bug, we shouldn't be creating a deletion
        # record if we've never seen it, probably, but we have a test in
        # FullIntegrationTest checking that it exists.
        HydrationCacheEntry.from(Figgy.DeletionRecord.from(resource), cache_version)
      end
    else
      delete_if_seen(resource.id, resource, cache_version)
    end
  end

  def to_hydration_cache_entry(
        resource = %{internal_resource: internal_resource, id: id},
        cache_version
      )
      when internal_resource in @collection_types do
    combined_resource = Figgy.Resource.to_combined(resource)

    if process?(combined_resource.resource) do
      HydrationCacheEntry.from(combined_resource, cache_version)
    else
      delete_if_seen(id, combined_resource, cache_version)
    end
  end

  def to_hydration_cache_entry(_resource, _cache_version), do: nil

  # We're being asked by a HydrationCacheEntry, convert appropriately.
  def process?(
        resource = %{
          "internal_resource" => _
        }
      ) do
    # Convert all the top-level keys into atoms if possible, should cover all
    # the Figgy.Resource properties. If not, String.to_existing_atom will
    # raise.
    atom_map = for {key, val} <- resource, into: %{}, do: {String.to_existing_atom(key), val}
    process?(atom_map)
  end

  # Collections / EphemeraProjects must be published
  def process?(%{
        internal_resource: internal_resource,
        metadata: %{
          "publish" => ["1"]
        }
      })
      when internal_resource in @collection_types do
    true
  end

  # Scanned resources must be complete, open, and a member of an allowed
  # collection.
  def process?(
        resource = %{
          internal_resource: "ScannedResource",
          state: ["complete"],
          visibility: ["open"],
          member_of_collection_ids: [_ | _]
        }
      ) do
    member_of_allowed_collection?(resource)
  end

  # ScannedResources must not have empty members.
  def process?(
        combined_figgy_resource = %Figgy.CombinedFiggyResource{
          resource: %{internal_resource: "ScannedResource"}
        }
      ) do
    combined_figgy_resource.persisted_member_ids != []
  end

  # Ephemera Folders must be complete and open.
  def process?(%{
        internal_resource: "EphemeraFolder",
        state: ["complete"],
        visibility: ["open"]
      }) do
    true
  end

  # Ephemera Folders must not have empty members.
  def process?(
        combined_figgy_resource = %Figgy.CombinedFiggyResource{
          resource: %{internal_resource: "EphemeraFolder"}
        }
      ) do
    combined_figgy_resource.persisted_member_ids != []
  end

  def process?(_resource), do: false

  defp delete_if_seen(record_id, source, cache_version) do
    if IndexingPipeline.get_hydration_cache_entry!(record_id, cache_version) do
      HydrationCacheEntry.from(Figgy.DeletionRecord.from(source), cache_version)
    end
  end

  defp member_of_allowed_collection?(resource) do
    collection_ids = Enum.map(resource.member_of_collection_ids, & &1["id"])
    Enum.any?(collection_ids, &ResourceTypeRegistry.allowed_collection?/1)
  end

  def related_records(
        %{updated_at: timestamp, id: id, internal_resource: internal_resource},
        cache_version
      )
      when internal_resource in @related_record_types do
    IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)
    |> Stream.map(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> to_hydration_cache_entry(cache_version)
    end)
  end

  def related_records(_resource, _cache_version), do: []

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
