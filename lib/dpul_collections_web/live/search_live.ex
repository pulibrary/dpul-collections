defmodule DpulCollectionsWeb.SearchLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.Solr

  defmodule Item do
    defstruct [:id, :title]
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    filters = %{
      q: params["q"],
      sort_by: valid_sort_by(params),
      page: (params["page"] || "1") |> String.to_integer(),
      per_page: (params["per_page"] || "10") |> String.to_integer()
    }

    solr_response = Solr.query(filters)

    items =
      solr_response["docs"]
      |> Enum.map(fn item ->
        %Item{id: item["id"], title: item["title_ss"]}
      end)

    socket =
      assign(socket,
        filters: filters,
        items: items,
        total_items: solr_response["numFound"]
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <form phx-submit="search" phx-change="filter">
      <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
        <div class="grid grid-cols-4">
          <input class="col-span-3" type="text" name="q" value={@filters.q} />
          <button class="col-span-1 font-bold uppercase" type="submit">
            Search
          </button>
        </div>
        <div class="grid grid-cols-8">
          <label class="flex items-center font-bold uppercase" for="sort-by">sort by:</label>
          <select class="col-span-2" name="sort-by">
            <%= Phoenix.HTML.Form.options_for_select(
              ["relevance", "id"],
              @filters.sort_by
            ) %>
          </select>
        </div>
      </div>
    </form>
    <div class="grid grid-flow-row auto-rows-max gap-8">
      <.search_item :for={item <- @items} item={item} />
    </div>
    <div class="text-center bg-white max-w-5xl mx-auto text-lg py-8">
      <div class="">
        <.link :if={@filters.page > 1} phx-click="paginate" phx-value-page={@filters.page - 1}>
          Previous
        </.link>
        <.link
          :for={{page_number, current_page?} <- pages(@filters, @total_items)}
          class={if current_page?, do: "active"}
          phx-click="paginate"
          phx-value-page={page_number}
        >
          <%= page_number %>
        </.link>
        <.link
          :if={more_pages?(@filters, @total_items)}
          phx-click="paginate"
          phx-value-page={@filters.page + 1}
        >
          Next
        </.link>
      </div>
    </div>
    """
  end

  attr :item, Item, required: true

  def search_item(assigns) do
    ~H"""
    <div class="item">
      <div class="underline text-lg"><%= @item.title %></div>
      <div><%= @item.id %></div>
    </div>
    """
  end

  def handle_event("search", params, socket) do
    params = %{q: params["q"], sort_by: params["sort-by"]} |> clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("filter", params, socket) do
    params = %{socket.assigns.filters | sort_by: params["sort-by"]} |> clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) when page != "..." do
    params = %{socket.assigns.filters | page: page} |> clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("paginate", _, socket) do
    {:noreply, socket}
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(relevance id) do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_), do: :relevance

  # Remove KV pairs with nil or empty string values
  defp clean_params(params) do
    params
    |> Enum.filter(fn {_, v} -> v != "" end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end

  defp more_pages?(filters, total_items) do
    filters.page * filters.per_page < total_items
  end

  defp pages(filters, total_items) do
    page_count = ceil(total_items / filters.per_page)
    page_range = (filters.page - 2)..(filters.page + 2)

    pages =
      for page_number <- page_range,
          page_number > 0 do
        if page_number <= page_count do
          current_page? = page_number == filters.page
          {page_number, current_page?}
        end
      end

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
