defmodule DpulCollections.IndexingPipeline.Figgy.IndexingConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy.TransformationCacheEntry records and indexes
  them into Solr.
  """
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.DatabaseProducer
  alias DpulCollections.Solr
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
      producer_options: {Figgy.IndexingProducerSource, cache_version},
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
  # return the message so we can handle it in the batch
  @spec handle_message(any(), Broadway.Message.t(), %{required(:cache_version) => integer()}) ::
          Broadway.Message.t()
  def handle_message(_processor, message, %{cache_version: _cache_version}) do
    message
  end

  @impl Broadway
  @spec handle_batch(any(), list(Broadway.Message.t()), any(), any()) ::
          list(Broadway.Message.t())
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
    |> Enum.map(&unwrap/1)
    |> Solr.add()

    messages
  end

  defp unwrap(%Broadway.Message{data: %Figgy.TransformationCacheEntry{data: data}}) do
    data
  end
end
