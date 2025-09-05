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

  def filter_and_process(resource = %Figgy.Resource{id: id}, cache_version) do
    case resource do
      # Process open/complete EphemeraFolders
      %{internal_resource: "EphemeraFolder", state: ["complete"], visibility: ["open"]} ->
        {:ok, marker_record(resource)}

      # Process EphemeraFolders that were processed before otherwise - we wanna
      # delete them.
      %{internal_resource: "EphemeraFolder"} ->
        existing_resource = IndexingPipeline.get_hydration_cache_entry!(id, cache_version)

        if existing_resource do
          {:delete,
           %Figgy.DeletionRecord{
             marker: CacheEntryMarker.from(resource),
             internal_resource: "EphemeraFolder",
             id: resource.id
           }}
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
          {:delete,
           %Figgy.DeletionRecord{
             marker: CacheEntryMarker.from(resource),
             internal_resource: "EphemeraFolder",
             id: resource_id
           }}
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

  def marker_record(resource) do
    marker = CacheEntryMarker.from(resource)

    %{marker: marker}
    |> Map.merge(Figgy.Resource.to_hydration_cache_attrs(resource))
  end

  @impl Broadway
  # pass through messages and write to cache in batcher to avoid race condition
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: %{
            internal_resource: internal_resource
          }
        },
        %{cache_version: cache_version}
      )
      when internal_resource in [
             "EphemeraFolder",
             "DeletionMarker",
             "EphemeraProject",
             "EphemeraBox",
             "EphemeraTerm",
             "FileSet"
           ] do
    case filter_and_process(message.data, cache_version) do
      {:ok, record} ->
        message |> Broadway.Message.put_data(record)

      {:related_resource, record} ->
        message |> Broadway.Message.put_data(%{related_resource: record})

      # Not sure why we just pass this through...
      {:delete, record} ->
        message |> Broadway.Message.put_data(record)

      {:skip, _record} ->
        message |> Broadway.Message.put_batcher(:noop)
    end
  end

  # If it's not selected above, ack the message but don't do anything with it.
  def handle_message(_processor, message, _state) do
    message
    |> Broadway.Message.put_batcher(:noop)
  end

  defp write_to_hydration_cache(
         %Broadway.Message{
           data: %Figgy.DeletionRecord{
             marker: marker,
             id: id,
             internal_resource: internal_resource
           }
         },
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

    {:ok, response}
  end

  defp write_to_hydration_cache(
         %Broadway.Message{
           data: %{
             marker: marker,
             handled_data: data,
             related_data: related_data,
             related_ids: related_ids,
             source_cache_order: source_cache_order,
             source_cache_order_record_id: source_cache_order_record_id
           }
         },
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

  defp write_to_hydration_cache(
         %Broadway.Message{
           data: %{
             related_resource: %{id: id, updated_at: timestamp}
           }
         },
         cache_version
       ) do
    related_record_ids =
      IndexingPipeline.get_related_hydration_cache_record_ids!(id, timestamp, cache_version)

    related_records = IndexingPipeline.get_figgy_resources(related_record_ids)

    related_records
    |> Enum.map(&Figgy.Resource.to_hydration_cache_attrs(&1))
    |> Enum.each(&update_related_hydration_cache_entry(&1, cache_version))

    {:ok, ""}
  end

  defp update_related_hydration_cache_entry(
         %{
           handled_data: data = %{id: resource_id},
           related_data: related_data,
           related_ids: related_ids,
           source_cache_order: source_cache_order,
           source_cache_order_record_id: source_cache_order_record_id
         },
         cache_version
       ) do
    {:ok, response} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: resource_id,
        related_ids: related_ids,
        source_cache_order: source_cache_order,
        source_cache_order_record_id: source_cache_order_record_id,
        data: data,
        related_data: related_data
      })

    {:ok, response}
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, %{cache_version: cache_version}) do
    Enum.each(messages, &write_to_hydration_cache(&1, cache_version))
    messages
  end

  def handle_batch(:noop, messages, _batch_info, _state) do
    messages
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
