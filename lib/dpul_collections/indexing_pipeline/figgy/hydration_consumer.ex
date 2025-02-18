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
        default: []
      ],
      batchers: [
        default: [batch_size: options[:batch_size]],
        noop: [batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version]}
    )
  end

  @impl Broadway
  # pass through messages and write to cache in batcher to avoid race condition
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: %{
            internal_resource: internal_resource,
            metadata: %{"state" => state, "visibility" => visibility}
          }
        },
        %{cache_version: _cache_version}
      )
      when internal_resource in ["EphemeraFolder"] and state == ["complete"] and
             visibility == ["open"] do
    marker = CacheEntryMarker.from(message)

    message_map =
      %{marker: marker, incoming_message_data: message.data}
      |> Map.merge(Figgy.Resource.to_hydration_cache_attrs(message.data))

    message
    |> Broadway.Message.put_data(message_map)
  end

  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: %{
            internal_resource: internal_resource
          }
        },
        %{cache_version: _cache_version}
      )
      when internal_resource in ["EphemeraTerm"] do
    marker = CacheEntryMarker.from(message)

    message_map =
      %{marker: marker, incoming_message_data: message.data}
      |> Map.merge(Figgy.Resource.to_hydration_cache_attrs(message.data))

    message
    |> Broadway.Message.put_data(message_map)
  end

  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: %{
            internal_resource: internal_resource,
            metadata: %{
              "resource_type" => [resource_type]
            }
          }
        },
        %{cache_version: _cache_version}
      )
      when internal_resource in ["DeletionMarker"] and
             resource_type in ["EphemeraFolder", "EphemeraTerm"] do
    marker = CacheEntryMarker.from(message)

    message_map =
      %{marker: marker, incoming_message_data: message.data}
      |> Map.merge(Figgy.Resource.to_hydration_cache_attrs(message.data))

    message
    |> Broadway.Message.put_data(message_map)
  end

  # If it's not selected above, ack the message but don't do anything with it.
  def handle_message(_processor, message, _state) do
    message
    |> Broadway.Message.put_batcher(:noop)
  end

  defp write_to_hydration_cache(
         %Broadway.Message{
           data: %{marker: marker, handled_data: data, related_data: related_data}
         },
         cache_version
       ) do
    # store in HydrationCache:
    # - data (blob) - this is the record
    # - cache_order (datetime) - this is our own new timestamp for this table
    # - cache_version (this only changes manually, we have to hold onto it as state)
    # - record_id (varchar) - the figgy UUID
    # - source_cache_order (datetime) - the figgy updated_at
    {:ok, response} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: marker.id,
        source_cache_order: marker.timestamp,
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
