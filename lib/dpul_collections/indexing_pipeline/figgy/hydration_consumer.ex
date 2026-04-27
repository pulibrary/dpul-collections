defmodule DpulCollections.IndexingPipeline.Figgy.HydrationConsumer do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy
  alias DpulCollections.IndexingPipeline.Figgy.ResourceTypeRegistry
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
    case Figgy.Resource.to_combined_resources(resource,
           cache_version: cache_version,
           persist: true
         ) do
      {:ok, _combined_resources} -> message
      {:error, _} -> Broadway.Message.put_batcher(message, :noop)
    end

    # with {:ok, combined_resources} <- Figgy.Resource.to_combined_resource(resource, persist: true)
    # resource
    # |> process(cache_version)
    # |> persist(cache_version)
    # |> store_result(message)
  end

  @impl Broadway
  def handle_batch(:default, messages, _batch_info, _state) do
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
