defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Solr

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max gap-10">
      <form phx-submit="search">
        <div class="grid grid-cols-4">
          <input class="col-span-3" type="text" name="q" value={@q} />
          <button class="col-span-1" type="submit">
            Search
          </button>
        </div>
      </form>
      <h3 class="text-5xl">Explore Our Digital Collections</h3>
      <p class="text-lg">
        We invite you to be inspired by our globally diverse collections of <%= @item_count %> Ephemera items. We can't wait to see how you use these materials to support your unique research.
      </p>
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  # Remove KV pairs with nil or empty string values
  defp clean_params(params) do
    params
    |> Enum.filter(fn {_, v} -> v != "" end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end
end
