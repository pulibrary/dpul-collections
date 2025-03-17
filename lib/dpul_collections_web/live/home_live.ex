defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}
  alias DpulCollectionsWeb.Live.Helpers

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil,
        recent_items:
          Solr.recently_digitized(5)["docs"]
          |> Enum.map(&Item.from_solr(&1))
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max gap-20">
      <div>
        <form phx-submit="search">
          <div class="grid grid-cols-4">
            <input class="col-span-4 md:col-span-3" type="text" name="q" value={@q} />
            <button class="col-span-4 md:col-span-1 btn-primary" type="submit">
              <%= gettext("Search") %>
            </button>
          </div>
        </form>
      </div>
      <div id="welcome" class="grid place-self-center gap-10 max-w-prose">
        <h3 class="text-5xl text-center"><%= gettext("Explore Our Digital Collections") %></h3>
        <p class="text-xl text-center">
          <%= gettext("We invite you to be inspired by our globally diverse collections of") %> <%= @item_count %> <%= gettext(
            "Ephemera items. We can't wait to see how you use these materials to support your unique research."
          ) %>
        </p>
      </div>
      <div class="grid place-self-center">
        <div id="browse-callout" class="btn-primary p-6 h-fit">
          <.link class="flex text-center" navigate={~p"/browse"}>
            Browse items across all collections
          </.link>
        </div>
      </div>
      <h2 class="uppercase font-bold text-3xl"><%= gettext("Recent Items") %></h2>
      <div class="grid grid-cols-5 gap-6 pt-5">
        <DpulCollectionsWeb.BrowseLive.browse_item :for={item <- @recent_items} item={item} />
      </div>
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
