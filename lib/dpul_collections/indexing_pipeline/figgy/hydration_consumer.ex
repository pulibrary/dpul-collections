defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
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
        default: [batch_size: options[:batch_size]],
        noop: [batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version], type: :figgy_hydrator}
    )
  end

  def initial_classification(resource = %Figgy.Resource{id: id}, cache_version) do
    case resource do
      # Process open/complete EphemeraFolders
      %{internal_resource: "EphemeraFolder", state: ["complete"], visibility: ["open"]} ->
        {:update, resource}

      # Process EphemeraFolders that were processed before otherwise - we wanna
      # delete them.
      %{internal_resource: "EphemeraFolder"} ->
        existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

        if existing_resource do
          {:delete, resource}
        else
          {:skip, resource}
        end

      %{
        internal_resource: "DeletionMarker",
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: ["EphemeraFolder"]
      } ->
        existing_resource =
          IndexingPipeline.get_hydration_cache_entry!(resource_id, cache_version)

        # Same as above branch..
        if existing_resource do
          {:delete, resource}
        else
          {:skip, resource}
        end

      # For related resources, send a special key.
      %{internal_resource: internal_resource}
      when internal_resource in ["EphemeraProject", "EphemeraBox", "EphemeraTerm", "FileSet"] ->
        {:related_resource, resource}

      _ ->
        {:skip, resource}
    end
  end

  # Resources we're updating need to become combined figgy resources.
  def enrich({:update, resource}, _cache_version) do
    marker = CacheEntryMarker.from(resource)

    {:update,
     %{marker: marker}
     |> Map.merge(Figgy.Resource.to_hydration_cache_attrs(resource))}
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

  @impl Broadway
  # pass through messages and write to cache in batcher to avoid race condition
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data:
            resource = %{
              internal_resource: internal_resource
            }
        },
        %{cache_version: cache_version}
      ) do
    resource
    |> to_message_data(cache_version)
    |> store_result(message)
  end

  # Described as a sentence, the hydration consumer, for each resource:
  # Classify (Update/Delete/Skip)
  # Enriches (Add data to the record before conversion)
  # Post-Classification (If the extra data changes the classification, do it
  #   here.)
  # Converts for storage
  # Stores in message
  def to_message_data(resource, cache_version) do
    resource
    # Determine early on if we're deleting, skipping, or updating.
    |> initial_classification(cache_version)
    # Add or convert resource
    |> enrich(cache_version)
    # |> post_classification # Determine if after enrichment we should continue updating, delete, or skip.
    # |> convert for persistence
  end

  def store_result({:related_resource, record}, message),
    do: Broadway.Message.put_data(message, {:related_resource, record})

  def store_result({:skip, _record}, message), do: Broadway.Message.put_batcher(message, :noop)

  def store_result({:update, record}, message),
    do: Broadway.Message.put_data(message, {:update, record})

  def store_result({:delete, record}, message),
    do: Broadway.Message.put_data(message, {:delete, record})

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, %{cache_version: cache_version}) do
    messages
    |> Enum.map(&Map.get(&1, :data))
    # Just in case we move to related resources being enriched to multiple
    # resource operations in a list.
    |> List.flatten()
    |> Enum.each(&persist(&1, cache_version))

    # Enum.each(messages, &write_to_hydration_cache(&1, cache_version))
    messages
  end

  def handle_batch(:noop, messages, _batch_info, _state) do
    messages
  end

  defp persist(
         {:delete,
          %Figgy.DeletionRecord{
            marker: marker,
            id: id,
            internal_resource: internal_resource
          }},
         cache_version
       ) do
    {:ok, response} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: id,
        related_ids: [],
        source_cache_order: marker.timestamp,
        source_cache_order_record_id: id,
        data: %{internal_resource: internal_resource, id: id, metadata: %{"deleted" => true}}
      })
  end

  defp persist(
         {:update,
          %{
            marker: marker,
            handled_data: data,
            related_data: related_data,
            related_ids: related_ids,
            source_cache_order: source_cache_order,
            source_cache_order_record_id: source_cache_order_record_id
          }},
         cache_version
       ) do
    # store in HydrationCache:
    # - data (blob) - this is the record
    # - cache_order (datetime) - this is our own new timestamp for this table
    # - cache_version (this only changes manually, we have to hold onto it as state)
    # - record_id (varchar) - the figgy UUID
    # - source_cache_order (datetime) - most recent figgy or related resource updated_at
    # - source_cache_order_record_id (varchar) - record id of the source_cache_order value
    {:ok, response} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: marker.id,
        related_ids: related_ids,
        source_cache_order: source_cache_order,
        source_cache_order_record_id: source_cache_order_record_id,
        data: data,
        related_data: related_data
      })

    {:ok, response}
  end

  defp persist(
         {:related_resource, %Figgy.Resource{id: id, updated_at: timestamp}},
         cache_version
       ) do
    related_record_ids =
      IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)

    related_records = IndexingPipeline.get_figgy_resources(related_record_ids)

    related_records
    |> Enum.map(&Figgy.Resource.populate_virtual/1)
    |> Enum.map(&to_message_data(&1, cache_version))
    |> Enum.map(&persist(&1, cache_version))

    {:ok, ""}
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
