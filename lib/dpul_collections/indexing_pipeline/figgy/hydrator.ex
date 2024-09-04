defmodule DpulCollections.IndexingPipeline.Figgy.Hydrator do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.FiggyProducer
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
      producer_module: FiggyProducer,
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
  # Only write to the cache if it's an ephemera folder
  def handle_message(
        _processor,
        message = %Broadway.Message{data: %{internal_resource: "EphemeraFolder"}},
        %{cache_version: cache_version}
      ) do
    write_to_hydration_cache(message, cache_version)

    message
  end

  @impl Broadway
  # Only write to the cache if it's an ephemera term
  def handle_message(
        _processor,
        message = %Broadway.Message{data: %{internal_resource: "EphemeraTerm"}},
        %{cache_version: cache_version}
      ) do
    write_to_hydration_cache(message, cache_version)

    message
  end

  @impl Broadway
  # fallback so we acknowledge messages we intentionally don't write
  def handle_message(_processor, message, %{cache_version: _cache_version}) do
    message
  end

  defp write_to_hydration_cache(message, cache_version) do
    # store in HydrationCache:
    # - data (blob) - this is the record
    # - cache_order (datetime) - this is our own new timestamp for this table
    # - cache_version (this only changes manually, we have to hold onto it as state)
    # - record_id (varchar) - the figgy UUID
    # - source_cache_order (datetime) - the figgy updated_at
    {:ok, _} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: message.data.id,
        source_cache_order: message.data.updated_at,
        data: message.data |> Map.from_struct() |> Map.delete(:__meta__)
      })
  end

  @impl Broadway
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
  end
end
