defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.Live.Helpers

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
          <input class="col-span-4 md:col-span-3" type="text" name="q" value={@q} />
          <button class="col-span-4 md:col-span-1 btn-primary" type="submit">
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
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
