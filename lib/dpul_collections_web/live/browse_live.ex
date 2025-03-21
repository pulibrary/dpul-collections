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
            Solr.random(50, given_seed)["docs"]
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
      <h1 class="uppercase font-bold text-4xl col-span-3"><%= gettext("Browse") %></h1>
      <button
        class="col-span-1 btn-primary shadow-[-6px_6px_0px_0px_rgba(0,77,112,0.50)] hover:shadow-[-4px_4px_0px_0px_rgba(0,77,112,0.75)] hover:bg-gray-800 transform rounded-lg border border-solid border-gray-700 transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
        phx-click="randomize"
      >
        <%= gettext("Randomize") %>
      </button>
    </div>
    <div class="grid grid-cols-3 gap-6 pt-5">
      <.browse_item :for={item <- @items} item={item} />
    </div>
    """
  end

  attr :item, Item, required: true

  def browse_item(assigns) do
    ~H"""
    <div
      id={"item-#{@item.id}"}
      class="flex flex-col rounded-lg overflow-hidden drop-shadow-[0.5rem_0.5rem_0.5rem_rgba(148,163,184,0.75)]"
    >
      <div class="h-[25rem]">
        <div :if={@item.file_count == 1} class="grid grid-cols-1 gap-[2px] bg-slate-400 h-[100%]">
          <.thumb thumb={thumbnail_service_url(@item)} />
        </div>

        <div
          :if={@item.file_count > 1}
          class="grid grid-cols-1 gap-[2px] bg-slate-400 h-[75%] overflow-hidden"
        >
          <.thumb thumb={thumbnail_service_url(@item)} />
        </div>
        <div class="bg-slate-400 grid grid-cols-4 gap-[2px] pt-[2px] h-[25%]">
          <.thumb
            :for={{thumb, thumb_num} <- thumbnail_service_urls(4, @item.image_service_urls)}
            :if={@item.file_count}
            thumb={thumb}
            thumb_num={thumb_num}
          />
        </div>
      </div>
      <div class="border-t-[2px] border-slate-400 flex-1 px-6 py-4 bg-white">
        <h2 class="text-2xl font-bold pt-4">
          <.link navigate={@item.url} class="item-link"><%= @item.title %></.link>
        </h2>
        <p class="text-gray-700 text-base"><%= @item.date %></p>
      </div>
      <div :if={@item.file_count > 1} class="absolute bg-lime-100 top-0 right-0 z-10 h-10 p-2">
        <%= @item.file_count %> pages
      </div>
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
      class="thumbnail bg-slate-400 text-white h-full w-full object-cover"
      src={thumbnail_url(assigns)}
      alt="thumbnail image"
    />
    """
  end

  def thumbnail_url(%{thumb: thumb, thumb_num: thumb_num}) when is_number(thumb_num) do
    "#{thumb}/square/100,100/0/default.jpg"
  end

  def thumbnail_url(%{thumb: thumb}) do
    "#{thumb}/square/350,350/0/default.jpg"
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
