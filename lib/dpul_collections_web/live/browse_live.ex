defmodule DpulCollectionsWeb.BrowseLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    given_seed = params["r"]

    if given_seed do
      socket =
        socket
        |> assign(
          items:
            Solr.random(500, given_seed)["docs"]
            |> Enum.map(&Item.from_solr(&1))
        )

      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..3000)}", replace: true)}
    end
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..3000)}")}
  end

  def render(assigns) do
    ~H"""
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10 grid-cols-4">
      <h1 class="text-2xl col-span-3"><%= gettext("Browse") %></h1>
      <button class="col-span-1 btn-primary" phx-click="randomize">
        <%= gettext("Randomize") %>
      </button>
    </div>
    <div class="grid grid-cols-2 gap-6">
      <.browse_item :for={item <- @items} item={item} />
    </div>
    """
  end

  attr :item, Item, required: true

  def browse_item(assigns) do
    ~H"""
    <div id={"item-#{@item.id}"} class="item">
      <div class="grid grid-cols-2 gap-3">
        <.thumb :if={@item.page_count} thumb={thumbnail_service_url(@item)} divisor={2} />
        <div class="grid grid-cols-2 gap-3">
          <.thumb
            :for={{thumb, thumb_num} <- thumbnail_service_urls(4, @item.image_service_urls)}
            :if={@item.page_count}
            thumb={thumb}
            thumb_num={thumb_num}
          />
        </div>
      </div>
      <h2 class="underline text-2xl font-bold pt-4">
        <.link navigate={@item.url} class="item-link"><%= @item.title %></.link>
      </h2>
      <div class="text-xl"><%= @item.date %></div>
    </div>
    """
  end

  defp thumbnail_service_urls(max_thumbnails, image_service_urls) do
    # Truncate image service urls to max value
    image_service_urls
    |> Enum.slice(1, max_thumbnails)
    |> Enum.with_index()
  end

  def thumb(assigns) do
    ~H"""
    <img
      class="thumbnail border border-solid border-gray-400"
      src={"#{@thumb}/square/350,350/0/default.jpg"}
      alt="thumbnail image"
      style="
        background-color: lightgray;"
      width="350"
      height="350"
    />
    """
  end

  defp thumbnail_service_url(%{primary_thumbnail_service_url: thumbnail_url})
       when is_binary(thumbnail_url) do
    thumbnail_url
  end

  defp thumbnail_service_url(%{image_service_urls: [url | _]}) do
    url
  end

  # TODO: default image?
  defp thumbnail_service_url(_), do: ""
end
