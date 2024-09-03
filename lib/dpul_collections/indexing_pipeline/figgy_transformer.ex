defmodule DpulCollections.IndexingPipeline.FiggyTransformer do
  @moduledoc """
  Broadway consumer that demands HydrationCacheEntry records, transforms
  them into Solr documents, and caches them in a database.
  """
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.FiggyTransformerProducer
  use Broadway

  @type start_opts ::
          {:cache_version, Integer}
          | {:producer_module, Module}
          | {:producer_options, any()}
          | {:batch_size, Integer}
  @spec start_link([start_opts()]) :: Broadway.on_start()
  def start_link(options \\ []) do
    default = [
      cache_version: 0,
      producer_module: FiggyTransformerProducer,
      producer_options: 0,
      batch_size: 10
    ]

    options = Keyword.merge(default, options)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {options[:producer_module], options[:producer_options]}
      ],
      processors: [
        default: []
      ],
      batchers: [
        default: [batch_size: options[:batch_size]]
      ],
      context: %{cache_version: options[:cache_version]}
    )
  end

  @impl Broadway
  # (note that the start_link param will populate _context)
  def handle_message(
        _processor,
        message = %Broadway.Message{data: %{data: %{"internal_resource" => "EphemeraFolder"}}},
        %{cache_version: cache_version}
      ) do
    write_to_transformation_cache(message, cache_version)

    message
  end

  @impl Broadway
  def handle_message(
        _processor,
        message = %Broadway.Message{data: %{data: %{"internal_resource" => "EphemeraTerm"}}},
        %{cache_version: cache_version}
      ) do
    update_linked_resources(message, cache_version)

    message
  end

  @impl Broadway
  # fallback so we acknowledge messages we intentionally don't write
  def handle_message(_processor, message, %{cache_version: _cache_version}) do
    message
  end

  defp write_to_transformation_cache(message, cache_version) do
    hydration_cache_entry = message.data
    solr_doc = transform_to_solr_document(hydration_cache_entry)

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
        source_cache_order: hydration_cache_entry |> Map.get(:source_cache_order),
        data: solr_doc
      })
  end

  defp transform_to_solr_document(hydration_cache_entry) do
    %{record_id: id} = hydration_cache_entry
    %{data: %{"metadata" => %{"title" => title}}} = hydration_cache_entry

    %{
      id: id,
      title_ssm: title
    }
  end

  def update_linked_resources(_message, _cache_version) do
    # TODO: Implement
    # In the initial case; find EphemeraFolder solr documents that contain a specific
    # EphemeraTerm and update the document with the new value of the term.
  end

  @impl Broadway
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
  end
end
