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
    |> process(cache_version)
    |> store_result(message)
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, %{cache_version: cache_version}) do
    messages
    # Get all the resources from the processing steps
    |> Enum.map(&Map.get(&1, :data))
    |> List.flatten()
    # Persist each of them to the HydrationCache.
    |> Enum.each(&persist(&1, cache_version))

    messages
  end

  def handle_batch(:noop, messages, _batch_info, _state) do
    messages
  end

  # If given a resource that has no virtual attributes and should, then populate
  # them - it probably came from get_figgy_resource!
  def process(
        resource = %Figgy.Resource{metadata: %{"visibility" => _visibility}, visibility: nil},
        cache_version
      ) do
    process(Figgy.Resource.populate_virtual(resource), cache_version)
  end

  def process(resource, cache_version) do
    resource
    # Determine early on if we're deleting, skipping, or updating.
    |> initial_classification(cache_version)
    # Add extra data
    |> enrich(cache_version)
    # Determine if after enrichment we should continue updating, delete, or skip.
    |> post_classification(cache_version)
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

  # If it's a related resource, get and process all records dependent on this
  # one.
  def enrich({:related_resource, %Figgy.Resource{id: id, updated_at: timestamp}}, cache_version) do
    related_record_ids =
      IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)

    related_records = IndexingPipeline.get_figgy_resources(related_record_ids)

    related_records
    |> Enum.map(&process(&1, cache_version))
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

  # Delete things which have no persisted members.
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

  def post_classification(resource_and_classification, _cache_version),
    do: resource_and_classification

  # There's a bunch of records, filter out the skips and put it in the message.
  def store_result(records, message) when is_list(records) do
    data =
      records
      |> Enum.filter(fn {action, _} -> action != :skip end)

    Broadway.Message.put_data(message, data)
  end

  def store_result({:skip, _record}, message), do: Broadway.Message.put_batcher(message, :noop)

  def store_result(data = {_action, _resource}, message),
    do: Broadway.Message.put_data(message, data)

  defp persist({action, resource}, cache_version) when action in [:delete, :update] do
    # Maybe move to HydrationCacheEntry.from?
    attributes = hydration_cache_attributes(resource, cache_version)

    {:ok, _response} =
      IndexingPipeline.write_hydration_cache_entry(attributes)
  end

  def hydration_cache_attributes(
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
      data: %{internal_resource: internal_resource, id: id, metadata: %{"deleted" => true}}
    }
  end

  # store in HydrationCache:
  # - data (blob) - this is the record
  # - cache_order (datetime) - this is our own new timestamp for this table
  # - cache_version (this only changes manually, we have to hold onto it as state)
  # - record_id (varchar) - the figgy UUID
  # - source_cache_order (datetime) - most recent figgy or related resource updated_at
  # - source_cache_order_record_id (varchar) - record id of the source_cache_order value
  def hydration_cache_attributes(
        combined_resource = %Figgy.CombinedFiggyResource{resource: resource},
        cache_version
      ) do
    %{
      cache_version: cache_version,
      record_id: resource.id,
      data: resource,
      related_data: combined_resource.related_data,
      related_ids: combined_resource.related_ids,
      source_cache_order: combined_resource.latest_updated_marker.timestamp,
      source_cache_order_record_id: combined_resource.latest_updated_marker.id
    }
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
