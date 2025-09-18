defmodule DpulCollections.IndexingPipeline.Figgy.TransformationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy.HydrationCacheEntry records, transforms
  them into Solr documents, and caches them in a database.
  """
  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
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
        default: [max_demand: 100, min_demand: 50, concurrency: System.schedulers_online() * 2]
      ],
      batchers: [
        default: [batch_size: options[:batch_size]],
        noop: [batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version], type: :figgy_transformer}
    )
  end

  @impl Broadway
  # pass through messages and write to cache in batcher to avoid race condition
  def handle_message(
        _processor,
        message = %Broadway.Message{
          data: resource = %HydrationCacheEntry{},
          metadata: %{marker: marker}
        },
        %{cache_version: cache_version}
      ) do
    resource
    |> process(cache_version)
    |> persist(marker, cache_version)
    |> store_result(message)
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, _state) do
    messages
  end

  def handle_batch(:noop, messages, _batch_info, _state) do
    messages
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

  # # We don't have the full resource yet, fetch it and re-classify.
  def initial_classification(%HydrationCacheEntry{id: id, data: nil}, cache_version) do
    initial_classification(
      IndexingPipeline.get_hydration_cache_entry!(id),
      cache_version
    )
  end

  def initial_classification(
        resource = %HydrationCacheEntry{data: %{"internal_resource" => internal_resource}},
        _cache_version
      )
      when internal_resource in ["EphemeraFolder"] do
    {:update, resource}
  end

  def initial_classification(resource, _cache_version) do
    {:skip, resource}
  end

  def enrich(
        {:update, hydration_cache_entry = %HydrationCacheEntry{}},
        _cache_version
      ) do
    solr_doc =
      hydration_cache_entry
      |> Figgy.HydrationCacheEntry.to_solr_document()

    # Cache solr document thumbnails
    %{solr_document: solr_doc}
    |> DpulCollections.Workers.CacheThumbnails.new()
    |> Oban.insert()

    {:update, solr_doc}
  end

  def enrich(resource_and_classification, _cache_version) do
    resource_and_classification
  end

  def post_classification(resource_and_classification, _cache_version) do
    resource_and_classification
  end

  def store_result({:skip, _record}, message), do: Broadway.Message.put_batcher(message, :noop)

  def store_result(_, message),
    do: message

  defp persist({action, solr_doc}, marker, cache_version)
       when action in [:delete, :update] do
    {:ok, _} =
      IndexingPipeline.write_transformation_cache_entry(%{
        cache_version: cache_version,
        record_id: solr_doc[:id],
        source_cache_order: marker.timestamp,
        data: solr_doc
      })
  end

  defp persist(resource_and_classification = {:skip, _}, _marker, _cache_version) do
    resource_and_classification
  end

  def start_over!(cache_version) do
    String.to_atom("#{__MODULE__}_#{cache_version}")
    |> Broadway.producer_names()
    |> Enum.each(&GenServer.cast(&1, :start_over))
  end
end
