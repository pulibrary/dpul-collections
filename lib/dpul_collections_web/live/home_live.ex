defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Solr
  alias DpulCollections.{Item, Solr}
  alias DpulCollectionsWeb.Live.Helpers

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil,
        items: [],
        search_state: nil,
        total_items: 0,
        random_seed: Enum.random(1..3000)
      )

    {:ok, socket, temporary_assigns: [item_count: nil]}
  end

  def handle_event("filter-date", params, socket) do
    params =
      %{
        socket.assigns.search_state
        | date_to: params["date-to"],
          date_from: params["date-from"]
      }
      |> Helpers.clean_params([:page, :per_page])

    socket = push_patch(socket, to: ~p"/?#{params}")
    {:noreply, socket}
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/?r=#{Enum.random(1..3000)}")}
  end

  def handle_params(params, _uri, socket) do
    search_state =
      DpulCollectionsWeb.SearchLive.SearchState.from_params(params)
      |> Map.put(:per_page, 60)
    solr_response = Solr.grouped_query(search_state)

    items = solr_response["grouped"]["max_year_i"]["groups"]
            |> Enum.reduce(%{}, &groups_to_map/2)

    total_items = solr_response["numFound"]

    socket =
      assign(socket,
        search_state: search_state,
        items: items,
        total_items: total_items,
        r: params["r"] || socket.assigns[:r]
      )

    {:noreply, socket}
  end

  defp groups_to_map(%{"groupValue" => year, "doclist" => %{"docs" => docs}}, acc) do
    acc
    |> Map.put(year, docs |> Enum.map(&Item.from_solr/1))
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max gap-20">
      <div>
        <form phx-submit="search">
          <div class="grid grid-cols-4">
            <input class="col-span-4 md:col-span-3" type="text" name="q" value={@q} />
            <button class="col-span-4 md:col-span-1 btn-primary" type="submit">
              Search
            </button>
          </div>
        </form>
      </div>
      <div id="welcome" class="grid place-self-center gap-10 max-w-prose">
        <h3 class="text-5xl text-center">Explore Our Digital Collections</h3>
        <p class="text-xl text-center">
          We invite you to be inspired by our globally diverse collections of <%= @item_count %> Ephemera items. We can't wait to see how you use these materials to support your unique research.
        </p>
      </div>
      <h3 class="text-5xl text-center">Browse Randomly by Year</h3>
      <.year_browse total_items={@total_items} items={@items} search_state={@search_state} />
    </div>
    """
  end

  def year_browse(assigns) do
    ~H"""
        <form
          id="date-filter"
          phx-submit="filter-date"
          class="grid md:grid-cols-[150px_200px_200px_200px] gap-2"
        >
          <label class="col-span-1 self-center font-bold uppercase" for="date-filter">
            filter by date:
          </label>
          <input
            class="col-span-1"
            type="text"
            placeholder="From"
            form="date-filter"
            name="date-from"
            value={@search_state.date_from}
          />
          <input
            class="col-span-1"
            type="text"
            placeholder="To"
            form="date-filter"
            name="date-to"
            value={@search_state.date_to}
          />
          <button class="col-span-1 md:col-span-1 btn-primary" type="submit">
            Apply
          </button>
        </form>
        <button class="col-span-1 btn-primary" phx-click="randomize">
          Randomize
        </button>
      <div :if={@total_items < 1}>
        <h3 class="text-4xl">No items found with those dates.</h3>
      </div>
      <.year_row
        :for={{year, docs} <- @items}
        year={year}
        docs={docs}
      />
    """
  end

  def year_row(assigns) do
    ~H"""
      <h3 class="text-3xl"><%= @year %></h3>
        <div class="grid grid-cols-6">
          <%= for doc <- @docs do %>
            <.link navigate={doc.url}>
            <img
              class="h-[350px] w-[350px] md:h-[225px] md:w-[225px] border border-solid border-gray-400"
              src={"#{doc.image_service_urls |> Enum.at(0)}/square/350,350/0/default.jpg"}
              alt={"image 1"}
              style="
              background-color: lightgray;"
              width="350"
              height="350"
              />
            </.link>
          <% end %>
        </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
