defmodule DpulCollectionsWeb.ItemLive do
  use DpulCollectionsWeb, :live_view
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item: nil
      )

    {:ok, socket}
  end

  def handle_params(%{"slug" => slug, "id" => id}, _uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr(:item_page)

    socket =
      cond do
        is_nil(item) ->
          assign(socket, item: nil)

        is_nil(item.slug) ->
          push_patch(socket, to: ~p"/item/#{item.id}", replace: true)

        slug != item.slug ->
          push_patch(socket, to: ~p"/i/#{item.slug}/item/#{item.id}", replace: true)

        true ->
          assign(socket, item: item)
      end

    {:noreply, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    item = Solr.find_by_id(id) |> Item.from_solr(:item_page)

    socket =
      cond do
        is_nil(item) -> assign(socket, item: nil)
        is_nil(item.slug) -> assign(socket, item: item)
        true -> push_patch(socket, to: ~p"/i/#{item.slug}/item/#{item.id}", replace: true)
      end

    {:noreply, socket}
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
