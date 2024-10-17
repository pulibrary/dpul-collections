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
      q: valid_query(params)
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
    <div class="grid grid-flow-row auto-rows-max gap-10">
      <form phx-submit="search">
        <div class="grid grid-cols-4">
          <input class="col-span-3" type="text" name="q" value={@filter.q} />
          <button class="col-span-1" type="submit">
            Search
          </button>
        </div>
      </form>
      <div class="grid grid-flow-row auto-rows-max gap-8">
        <.search_item :for={item <- @items} item={item} />
      </div>
    </div>
    """
  end

  attr :item, Item, required: true

  def search_item(assigns) do
    ~H"""
    <div class="item">
      <div class="font-bold text-lg"><%= @item.title %></div>
      <div><%= @item.id %></div>
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q}
    socket = push_patch(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  defp valid_query(%{"q" => ""}), do: nil
  defp valid_query(%{"q" => q}), do: q
  defp valid_query(_), do: nil
end
