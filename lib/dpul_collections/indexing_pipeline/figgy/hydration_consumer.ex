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
    |> persist(cache_version)
    |> store_result(message)
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, _state) do
    messages
  end

  def handle_batch(:noop, messages, _batch_info, _state) do
    messages
  end

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

  @related_record_types ["EphemeraProject", "EphemeraBox", "EphemeraTerm", "FileSet"]
  def process(resource, cache_version) do
    resource
    # Determine early on if we're deleting, skipping, or updating.
    |> initial_classification(cache_version)
    # Add extra data
    |> enrich(cache_version)
    # Determine if after enrichment we should continue updating, delete, or skip.
    |> post_classification(cache_version)
  end

  @spec initial_classification(resource :: %Figgy.Resource{}, cache_version :: integer) ::
          process_return()
  def initial_classification(resource = %Figgy.Resource{id: id}, cache_version) do
    case resource do
      # Process open/complete EphemeraFolders
      %{internal_resource: "EphemeraFolder", state: ["complete"], visibility: ["open"]} ->
        {:update, resource}

      # Process things that could be related records
      %{internal_resource: internal_resource} when internal_resource in @related_record_types ->
        {:update, resource}

      # Delete other EphemeraFolders that are already cached, otherwise we can
      # skip them.
      %{internal_resource: "EphemeraFolder"} ->
        existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

        if existing_resource do
          {:delete, resource}
        else
          {:skip, resource}
        end

      # Delete EphemeraFolders with DeletionMarkers if they're cached, otherwise
      # we can skip them.
      %{
        internal_resource: "DeletionMarker",
        metadata_resource_id: [%{"id" => resource_id}],
        metadata_resource_type: ["EphemeraFolder"]
      } ->
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

  # If it's a related resource, get ids of all records dependent on this one
  # one.
  @spec process(process_return(), cache_version :: integer) :: process_return()
  def enrich(
        {:update,
         %Figgy.Resource{id: id, updated_at: timestamp, internal_resource: internal_resource}},
        cache_version
      )
      when internal_resource in @related_record_types do
    related_record_ids =
      IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)

    {
      :update,
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
  def post_classification({:update, []}, _cache_version) do
    {:skip, []}
  end

  def post_classification(resource_and_classification, _cache_version),
    do: resource_and_classification

  @spec store_result(process_return(), message :: Broadway.Message.t()) ::
          Broadway.Message.t()
  def store_result({:skip, _record}, message), do: Broadway.Message.put_batcher(message, :noop)

  def store_result(_, message),
    do: message

  # If we're passed several IDs, process them in order and persist.
  @spec persist(process_return(), cache_version :: integer) ::
          {:ok, %Figgy.HydrationCacheEntry{}}
  defp persist(update = {:update, id_list = [id | _]}, cache_version) when is_binary(id) do
    # Do one at a time to prevent memory ballooning.
    id_list
    |> Enum.each(fn id ->
      IndexingPipeline.get_figgy_resource!(id)
      |> process(cache_version)
      |> persist(cache_version)
    end)

    update
  end

  defp persist(process_return = {action, _resource}, cache_version)
       when action in [:delete, :update] do
    # Maybe move to HydrationCacheEntry.from?
    attributes = hydration_cache_attributes(process_return, cache_version)

    {:ok, _response} = IndexingPipeline.write_hydration_cache_entry(attributes)
  end

  defp persist({:skip, _}, _cache_version), do: {:skip, nil}

  @spec hydration_cache_attributes(
          %Figgy.DeletionRecord{} | %Figgy.CombinedFiggyResource{},
          cache_version :: integer
        ) :: %{
          :handled_data => map(),
          :related_data => Figgy.CombinedFiggyResource.related_data()
        }
  def hydration_cache_attributes({_action, resource}, cache_version),
    do: hydration_cache_attributes(resource, cache_version)

  # store in HydrationCache:
  # - cache_version (this only changes manually, we have to hold onto it as state)
  # - record_id (varchar) - the figgy UUID
  # - data (blob) - this is the record
  # - related_data (blob) - map of related data
  # - related_ids (array<string>) - array of IDs that are contained in
  #   related_data
  # - source_cache_order (datetime) - most recent figgy or related resource updated_at
  # - source_cache_order_record_id (varchar) - record id of the source_cache_order value
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
