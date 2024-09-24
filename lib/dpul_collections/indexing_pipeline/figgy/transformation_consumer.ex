defmodule DpulCollections.IndexingPipeline.Figgy.TransformationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy.HydrationCacheEntry records, transforms
  them into Solr documents, and caches them in a database.
  """
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
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
      producer_module: Figgy.TransformationProducer,
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
  @spec handle_message(any(), any(), %{required(:cache_version) => integer()}) :: Broadway.Message.t()
  def handle_message(
    _processor,
    message = %Broadway.Message{data: %{data: %{"internal_resource" => internal_resource}}},
    _state
  )
  when internal_resource in ["EphemeraFolder"] do
    solr_doc = transform_to_solr_document(message.data)
    message
    |> put_in([message.data, :data], solr_doc)
  end

  @impl Broadway
  @spec handle_message(any(), any(), %{required(:cache_version) => integer()}) ::
          Broadway.Message.t()
  def handle_message(_processor, message, %{cache_version: _cache_version}) do
    message
    |> put_in([message.data, :data], nil)
  end

  @impl Broadway
  @spec handle_batch(any(), list(Broadway.Message.t()), any(), any()) ::
          list(Broadway.Message.t())
  def handle_batch(_batcher, messages, _batch_info, %{cache_version: cache_version}) do
    Enum.each(messages, &write_to_transformation_cache(&1, cache_version))
    messages
  end

  @spec write_to_transformation_cache(Broadway.Message.t(), integer()) ::
          {:ok, %Figgy.TransformationCacheEntry{} | nil}
  defp write_to_transformation_cache(
         message = %Broadway.Message{data: %{data: solr_document}},
         cache_version
  ) do
    hydration_cache_entry = message.data
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
        data: solr_document
      })
  end

  defp write_to_transformation_cache(_, _), do: {:ok, nil}

  @spec transform_to_solr_document(%Figgy.HydrationCacheEntry{}) :: %{}
  defp transform_to_solr_document(hydration_cache_entry) do
    %{record_id: id} = hydration_cache_entry
    %{data: %{"metadata" => %{"title" => title}}} = hydration_cache_entry

    %{
      id: id,
      title_ss: title
    }
  end
end
