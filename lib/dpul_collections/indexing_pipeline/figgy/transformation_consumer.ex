defmodule DpulCollections.IndexingPipeline.Figgy.TransformationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy.HydrationCacheEntry records, transforms
  them into Solr documents, and caches them in a database.
  """
  alias Broadway.Message
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
      producer_options: {Figgy.TransformationProducerSource, cache_version},
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
        noop: [concurrency: 5, batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version]},
      partition_by: &partition/1
    )
  end

  def partition(msg) do
    :erlang.phash2(CacheEntryMarker.from(msg).id)
  end

  @impl Broadway
  @spec handle_message(any(), any(), %{required(:cache_version) => integer()}) ::
          Broadway.Message.t()
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: hydration_cache_entry = %{data: %{"internal_resource" => internal_resource}}
        },
        %{cache_version: _cache_version}
      )
      when internal_resource in ["EphemeraFolder"] do
    solr_doc = Figgy.HydrationCacheEntry.to_solr_document(hydration_cache_entry)

    # Cache solr document thumbnails
    %{solr_document: solr_doc}
    |> DpulCollections.Workers.CacheThumbnails.new()
    |> Oban.insert()

    marker = CacheEntryMarker.from(message)

    message
    |> Message.put_data(%{
      marker: marker,
      incoming_message_data: hydration_cache_entry,
      handled_data: solr_doc
    })
  end

  # If it's not matched above, put it in the no-op batcher - we want to ack it
  # but not save it.
  def handle_message(_processor, message, _) do
    message
    |> Message.put_batcher(:noop)
  end

  @impl Broadway
  @spec handle_batch(any(), list(Broadway.Message.t()), any(), any()) ::
          list(Broadway.Message.t())
  def handle_batch(:noop, messages, _, _) do
    messages
  end

  def handle_batch(:default, messages, _batch_info, %{cache_version: cache_version}) do
    Enum.each(messages, &write_to_transformation_cache(&1, cache_version))
    messages
  end

  @spec write_to_transformation_cache(Broadway.Message.t(), integer()) ::
          {:ok, %Figgy.TransformationCacheEntry{} | nil}
  defp write_to_transformation_cache(
         %Broadway.Message{
           data: %{incoming_message_data: hydration_cache_entry, handled_data: solr_doc}
         },
         cache_version
       ) do
    # store in TransformationCache:
    # - data (map) - this is the transformed solr document map
    # - cache_order (datetime) - this is our own new timestamp for this table
    # - cache_version (this only changes manually, we have to hold onto it as state)
    # - record_id (varchar) - the figgy UUID
    # - source_cache_order (datetime) - the hyrdation cache entry source_cache_order
    {:ok, _} =
      IndexingPipeline.write_transformation_cache_entry(%{
        cache_version: cache_version,
        record_id: hydration_cache_entry |> Map.get(:record_id),
        source_cache_order: hydration_cache_entry |> Map.get(:cache_order),
        data: solr_doc
      })
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
