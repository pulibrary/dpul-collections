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
    filter = %{
      q: params["q"],
      sort_by: valid_sort_by(params)
    }

    items =
      Solr.query(filter)
      |> Enum.map(fn item ->
        %Item{id: item["id"], title: item["title_ss"]}
      end)

    socket =
      assign(socket,
        filter: filter,
        items: items
      )

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <form phx-submit="search" phx-change="filter">
      <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
        <div class="grid grid-cols-4">
          <input class="col-span-3" type="text" name="q" value={@filter.q} />
          <button class="col-span-1 font-bold uppercase" type="submit">
            Search
          </button>
        </div>
        <div class="grid grid-cols-8">
          <label class="flex items-center font-bold uppercase" for="sort-by">sort by:</label>
          <select class="col-span-2" name="sort-by">
            <%= Phoenix.HTML.Form.options_for_select(
              ["relevance", "id"],
              @filter.sort_by
            ) %>
          </select>
        </div>
      </div>
    </form>
    <div class="grid grid-flow-row auto-rows-max gap-8">
      <.search_item :for={item <- @items} item={item} />
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

  def handle_event("search", %{"q" => q}, socket) do
    params = %{socket.assigns.filter | q: q} |> clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  def handle_event("filter", %{"sort-by" => sort_by}, socket) do
    params = %{socket.assigns.filter | sort_by: sort_by} |> clean_params()
    socket = push_patch(socket, to: ~p"/search?#{params}")
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
end
