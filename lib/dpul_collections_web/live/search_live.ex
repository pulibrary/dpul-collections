defmodule DpulCollectionsWeb.SearchLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.Live.Helpers

  defmodule Item do
    defstruct [:id, :title, :date]
  end

  defmodule SearchState do
    def from_params(params) do
      %{
        q: params["q"],
        sort_by: valid_sort_by(params),
        page: (params["page"] || "1") |> String.to_integer(),
        per_page: (params["per_page"] || "10") |> String.to_integer(),
        date_from: params["date_from"] || nil,
        date_to: params["date_to"] || nil
      }
    end

    defp valid_sort_by(%{"sort_by" => sort_by})
         when sort_by in ["relevance", "date_desc", "date_asc"] do
      String.to_existing_atom(sort_by)
    end

    defp valid_sort_by(_), do: :relevance
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    search_state = SearchState.from_params(params)
    solr_response = Solr.query(search_state)

    items =
      solr_response["docs"]
      |> Enum.map(fn item ->
        %Item{id: item["id"], title: item["title_ss"], date: item["display_date_s"]}
      end)

    total_items = solr_response["numFound"]

    socket =
      assign(socket,
        search_state: search_state,
        item_counter: item_counter(search_state, total_items),
        items: items,
        total_items: total_items
      )

    {:noreply, socket}
  end

  defp item_counter(_, 0), do: "No items found"

  defp item_counter(%{page: page, per_page: per_page}, total_items) do
    first_item = max(page - 1, 0) * per_page + 1
    last_page? = page * per_page >= total_items

    last_item =
      cond do
        last_page? -> total_items
        true -> first_item + per_page - 1
      end

    "#{first_item} - #{last_item} of #{total_items}"
  end

  def render(assigns) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
      <form id="search-form" phx-submit="search">
        <div class="grid grid-cols-4">
          <input class="col-span-3" type="text" name="q" value={@search_state.q} />
          <button class="col-span-1 font-bold uppercase" type="submit">
            Search
          </button>
        </div>
      </form>
      <div id="date-filter" class="grid grid-cols-8 gap-4">
        <label class="flex items-center font-bold uppercase" for="sort-by">filter by date: </label>
        <input
          class="col-span-1"
          type="text"
          placeholder="From"
          form="search-form"
          name="date-from"
          value={@search_state.date_from}
        />
        <input
          class="col-span-1"
          type="text"
          placeholder="To"
          form="search-form"
          name="date-to"
          value={@search_state.date_to}
        />
      </div>
      <form id="sort-form" phx-change="sort">
        <div class="grid grid-cols-8">
          <label class="col-span-1 flex items-center font-bold uppercase" for="sort-by">
            sort by:
          </label>
          <select class="col-span-1" name="sort-by">
            <%= Phoenix.HTML.Form.options_for_select(
              ["relevance", "date desc": "date_desc", "date asc": "date_asc"],
              @search_state.sort_by
            ) %>
          </select>
        </div>
      </form>
      <div id="item-counter">
        <span><%= @item_counter %></span>
      </div>
    </div>
    <div class="grid grid-flow-row auto-rows-max gap-8">
      <.search_item :for={item <- @items} item={item} />
    </div>
    <div class="text-center bg-white max-w-5xl mx-auto text-lg py-8">
      <.paginator
        page={@search_state.page}
        per_page={@search_state.per_page}
        total_items={@total_items}
      />
    </div>
    """
  end

  attr :item, Item, required: true

  def search_item(assigns) do
    ~H"""
    <div class="item">
      <div class="underline text-lg"><%= @item.title %></div>
      <div><%= @item.id %></div>
      <div><%= @item.date %></div>
    </div>
    """
  end

  def paginator(assigns) do
    ~H"""
    <div class="paginator">
      <.link :if={@page > 1} id="paginator-previous" phx-click="paginate" phx-value-page={@page - 1}>
        Previous
      </.link>
      <.link
        :for={{page_number, current_page?} <- pages(@page, @per_page, @total_items)}
        class={if current_page?, do: "active"}
        phx-click="paginate"
        phx-value-page={page_number}
      >
        <%= page_number %>
      </.link>
      <.link
        :if={more_pages?(@page, @per_page, @total_items)}
        id="paginator-next"
        phx-click="paginate"
        phx-value-page={@page + 1}
      >
        Next
      </.link>
    </div>
    """
  end

  def handle_event("search", params, socket) do
    params =
      %{
        socket.assigns.search_state
        | q: params["q"],
          date_to: params["date-to"],
          date_from: params["date-from"]
      }
      |> Helpers.clean_params([:page, :per_page])

    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("sort", params, socket) do
    params =
      %{socket.assigns.search_state | sort_by: params["sort-by"]}
      |> Helpers.clean_params([:page, :per_page])

    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) when page != "..." do
    params = %{socket.assigns.search_state | page: page} |> Helpers.clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("paginate", _, socket) do
    {:noreply, socket}
  end

  defp more_pages?(page, per_page, total_items) do
    page * per_page < total_items
  end

  defp pages(page, per_page, total_items) do
    page_count = ceil(total_items / per_page)
    page_range = (page - 2)..(page + 2)

    pages =
      for page_number <- page_range,
          page_number > 0 do
        if page_number <= page_count do
          current_page? = page_number == page
          {page_number, current_page?}
        end
      end

    # Add the prefix (1...) and postfix (...last_page)
    # tail element to the paginator.
    paginator_tail(:pre, 1, page_range) ++
      pages ++
      paginator_tail(:post, page_count, page_range)
  end

  defp paginator_tail(type, page, page_range) do
    cond do
      Enum.member?(page_range |> Enum.to_list(), page) -> []
      type == :pre -> [{page, false}, {"...", false}]
      type == :post -> [{"...", false}, {page, false}]
    end
  end
end
