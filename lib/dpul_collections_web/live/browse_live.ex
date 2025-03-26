defmodule DpulCollectionsWeb.BrowseLive do
  use DpulCollectionsWeb, :live_view
  import DpulCollectionsWeb.Gettext
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(items: [], pinned_items: [])

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    given_seed = params["r"]

    if given_seed do
      socket =
        socket
        |> assign(
          items:
            Solr.random(90, given_seed)["docs"]
            |> Enum.map(&Item.from_solr(&1))
        )

      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}", replace: true)}
    end
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}")}
  end

  def handle_event(
        "pin",
        %{"item_id" => id},
        socket = %{assigns: %{items: items, pinned_items: pinned_items}}
      ) do
    doc = items |> Enum.find(fn item -> item.id == id end)

    case Enum.find_index(pinned_items, fn pinned_item -> doc.id == pinned_item.id end) do
      nil ->
        {:noreply, socket |> assign(pinned_items: Enum.concat(pinned_items, [doc]))}

      idx ->
        socket = socket |> assign(pinned_items: List.delete_at(pinned_items, idx))
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <.pin_tracker>{length(@pinned_items)}</.pin_tracker>
    <div id="pinned-items" class="my-5 grid grid-flow-row auto-rows-max gap-10 grid-cols-1">
      <h1 class="uppercase font-bold text-4xl col-span-3">Pinned</h1>

      <div class="grid grid-flow-row auto-rows-max gap-8">
        <DpulCollectionsWeb.SearchLive.search_item :for={item <- @pinned_items} item={item} />
      </div>
    </div>
    <div class="my-5 grid grid-flow-row auto-rows-max gap-10 grid-cols-4">
      <h1 class="uppercase font-bold text-4xl col-span-3">{gettext("Browse")}</h1>
      <button
        class="col-span-1 btn-primary shadow-[-6px_6px_0px_0px_rgba(0,77,112,0.50)] hover:shadow-[-4px_4px_0px_0px_rgba(0,77,112,0.75)] hover:bg-gray-800 transform rounded-lg border border-solid border-gray-700 transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
        phx-click="randomize"
      >
        {gettext("Randomize")}
      </button>
    </div>
    <div class="grid grid-cols-3 gap-6 pt-5">
      <.browse_item :for={item <- @items} item={item} />
    </div>
    """
  end

  def pin_tracker(assigns) do
    ~H"""
    <div id="pin-tracker" class="fixed top-50 right-10">
      <div class="relative inline-flex w-fit">
        <div class="absolute bottom-auto left-auto right-0 top-0 z-10 inline-block -translate-y-1/2 translate-x-2/4 rotate-0 skew-x-0 skew-y-0 scale-x-100 scale-y-100 whitespace-nowrap rounded-full bg-red-600 px-1.5 py-1 text-center align-baseline text-xs font-bold leading-none text-white">
          {render_slot(@inner_block)}
        </div>
        <a href="#pinned-items">
          <span class="cursor-pointer mb-2 flex rounded bg-[#3eb991] px-6 py-2.5 text-xs font-medium uppercase leading-normal text-white shadow-md transition duration-150 ease-in-out hover:shadow-lg focus:shadow-lg focus:outline-none focus:ring-0 active:shadow-lg">
            <.icon name="hero-archive-box-solid" class="h-6 w-6 icon" />
          </span>
        </a>
      </div>
    </div>
    """
  end

  attr :item, Item, required: true

  def browse_item(assigns) do
    ~H"""
    <div
      id={"browse-item-#{@item.id}"}
      class="flex flex-col rounded-lg overflow-hidden drop-shadow-[0.5rem_0.5rem_0.5rem_rgba(148,163,184,0.75)]"
    >
      <div
        id={"pin-#{@item.id}"}
        phx-click={
          JS.push("pin")
          |> JS.toggle_class("bg-white", to: {:inner, ".icon"})
          |> JS.toggle_class("bg-black")
          |> JS.toggle_class("bg-white")
        }
        phx-value-item_id={@item.id}
        class="h-10 w-10 absolute left-0 top-0 cursor-pointer bg-white"
      >
        <.icon name="hero-archive-box-arrow-down-solid" class="h-10 w-10 icon" />
      </div>
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
          <.link navigate={@item.url} class="item-link">{@item.title}</.link>
        </h2>
        <p class="text-gray-700 text-base">{@item.date}</p>
      </div>
      <div :if={@item.file_count > 1} class="absolute bg-lime-100 top-0 right-0 z-10 h-10 p-2">
        {@item.file_count} pages
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
