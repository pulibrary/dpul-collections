defmodule DpulCollectionsWeb.BrowseLive do
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollectionsWeb.BrowseItem
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        items: [],
        liked_items: [],
        page_title: "Browse - Digital Collections",
        focused_item: nil
      )

    {:ok, socket}
  end

  @spec handle_params(nil | maybe_improper_list() | map(), any(), any()) :: {:noreply, any()}
  # If we've been asked to randomize, do it.
  def handle_params(%{"r" => given_seed}, _uri, socket) do
    socket =
      socket
      |> assign(
        items:
          Solr.random(90, given_seed)["docs"]
          |> Enum.map(&Item.from_solr(&1)),
        focused_item: nil
      )

    {:noreply, socket}
  end

  # If we're recommending items based on another item, do that.
  def handle_params(%{"focus_id" => focus_id}, _uri, socket) do
    item = Solr.find_by_id(focus_id) |> Item.from_solr()

    recommended_items =
      Solr.related_items(item, SearchState.from_params(%{}), 90)["docs"]
      |> Enum.map(&Item.from_solr/1)

    liked_items =
      cond do
        item.id in Enum.map(socket.assigns.liked_items, fn item -> item.id end) ->
          socket.assigns.liked_items

        # When we come to this link directly liked_items is empty - add the one
        # we're focusing.
        true ->
          [item | socket.assigns.liked_items]
      end

    {:noreply,
     socket |> assign(items: recommended_items, focused_item: item, liked_items: liked_items)}
  end

  # If neither, generate a random seed and display random items.
  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}", replace: true)}
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}")}
  end

  def handle_event(
        "like",
        %{"item_id" => id},
        socket = %{
          assigns: %{items: items, liked_items: liked_items}
        }
      ) do
    doc = items |> Enum.find(fn item -> item.id == id end)

    socket =
      case Enum.find_index(liked_items, fn liked_item -> doc.id == liked_item.id end) do
        nil ->
          socket |> assign(liked_items: [doc | liked_items])

        idx ->
          socket |> assign(liked_items: List.delete_at(liked_items, idx))
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="browse" class="content-area">
      <h1 id="browse-header" class="mb-2">{gettext("Browse")}</h1>
      <div :if={!@focused_item} class="text-2xl mb-5">
        "Like" a random item below to find items similar to it.
      </div>
      <div
        :if={@focused_item}
        class="mb-5 text-2xl gap-2 grid grid-cols-[12rem_1fr] h-[12rem] w-full items-center"
      >
        <div>
          <BrowseItem.thumb
            thumb={BrowseItem.thumbnail_service_url(@focused_item)}
            patch={~p"/browse/focus/#{@focused_item.id}"}
            class="min-h-0"
          />
        </div>
        <h3>
          Because you liked
          <.link href={@focused_item.url} class="font-bold" target="_blank">
            {@focused_item.title}
          </.link>
        </h3>
      </div>
      <.display_items {assigns} />
    </div>
    """
  end

  def display_items(assigns) do
    ~H"""
    <div>
      <.liked_items {assigns} />
      <div id="browse-items" class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5">
        <.browse_item :for={item <- @items} item={item} target="_blank" />
      </div>
    </div>
    """
  end

  def liked_items(assigns) do
    ~H"""
    <div
      id="liked-items"
      class={[
        "sticky top-0 left-0 bg-secondary z-10 justify-end grid grid-cols-[1fr_64px]"
      ]}
    >
      <div class="min-h-[94px] pt-2 text-right whitespace-nowrap h-full overflow-x-scroll overflow-y-hidden h-[64px] pr-2">
        <div
          :for={item <- @liked_items}
          class={[
            "liked-item w-[64px] h-[64px] inline-block ml-2",
            @focused_item && item.id == @focused_item.id && "border-accent border-2"
          ]}
        >
          <BrowseItem.thumb
            phx-click={JS.dispatch("dpulc:scrollTop")}
            thumb={BrowseItem.thumbnail_service_url(item)}
            patch={~p"/browse/focus/#{item.id}"}
          />
        </div>
      </div>
      <div class="h-full">
        <.link
          phx-click={JS.dispatch("dpulc:scrollTop")}
          patch="/browse"
          class="h-full w-[64px] col-span-1 btn-primary hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
          aria-label="View Random Items"
        >
          <.icon name="hero-arrow-path" class="h-6 w-6 icon" />
        </.link>
      </div>
    </div>
    """
  end
end
