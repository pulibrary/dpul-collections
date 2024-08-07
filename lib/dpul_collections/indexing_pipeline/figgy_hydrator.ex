defmodule DpulCollections.IndexingPipeline.FiggyHydrator do
  @moduledoc """
  Broadway consumer that demands Figgy records and caches them in the database.
  """
  use Broadway

  def start_link() do
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

  @impl true
  def handle_message(_processor, message, _context) do
    message
  end

  @impl true
  def handle_batch(_batcher, messages, _batch_info, _context) do
    messages
  end

end
