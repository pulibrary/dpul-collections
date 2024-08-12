defmodule DpulCollections.IndexingPipeline.FiggyHydrator do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  alias DpulCollections.IndexingPipeline
  use Broadway

  # TODO
  # this opts param will to give us the cache_version, then we need to set it
  def start_link(_opts) do
    producer_module = Application.fetch_env!(:dpul_collections, :producer_module)
    producer_options = Application.get_env(:dpul_collections, :producer_options, [])

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_module, producer_options}
      ],
      processors: [
        default: []
      ],
      batchers: [
        default: [batch_size: 10]
      ]
    )
  end

  @impl Broadway
  # (note that the start_link param will populate _context)
  def handle_message(_processor, message, _context) do
    # store in HydrationCache:
    # - data (blob) - this is the record
    # - cache_order (datetime) - this is our own new timestamp for this table
    # - cache_version (this only changes manually, we have to hold onto it as state)
    # - record_id (varchar) - the figgy UUID
    # - source_cache_order (datetime) - the figgy updated_at
    {:ok, _} =
      IndexingPipeline.create_hydration_cache_entry(%{
        cache_version: 0,
        record_id: message.data.id,
        source_cache_order: message.data.updated_at,
        data: message.data |> Map.from_struct() |> Map.delete(:__meta__)
      })

    message
  end

  @impl Broadway
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
  end
end
