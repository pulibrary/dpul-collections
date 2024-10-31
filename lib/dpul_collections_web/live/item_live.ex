defmodule DpulCollectionsWeb.ItemLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr()
    path = URI.parse(uri).path
    {:noreply, build_socket(socket, item, path)}
  end

  defp build_socket(socket, item, path) when item.url != path do
    push_patch(socket, to: item.url, replace: true)
  end

  defp build_socket(socket, item, _) do
    assign(socket, item: item)
  end

  # Render a message if no item was found in Solr.
  def render(assigns) when is_nil(assigns.item) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
      <span>Item not found</span>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10">
      <div class="item">
        <div class="underline text-lg"><%= @item.title %></div>
        <div><%= @item.id %></div>
        <div><%= @item.date %></div>
        <div><%= @item.page_count %></div>
      </div>
    </div>
    """
  end
end
