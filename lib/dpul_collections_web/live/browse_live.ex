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
  def handle_params(params, _uri, socket) do
    given_seed = params["r"]

    if given_seed do
      socket =
        socket
        |> assign(
          items:
            Solr.random(90, given_seed)["docs"]
            |> Enum.map(&Item.from_solr(&1)),
          focused_item: nil
        )

      {:noreply, socket}
    else
      if params["focus_id"] do
        item = Solr.find_by_id(params["focus_id"]) |> Item.from_solr()

        recommended_items =
          Solr.related_items(item, SearchState.from_params(%{}), 90)["docs"]
          |> Enum.map(&Item.from_solr/1)

        liked_items = [item | socket.assigns.liked_items] |> Enum.uniq_by(fn item -> item.id end)

        {:noreply,
         socket |> assign(items: recommended_items, focused_item: item, liked_items: liked_items)}
      else
        {:noreply,
         push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}", replace: true)}
      end
    end
  end

  def handle_event("randomize", _map, socket) do
    {:noreply, push_patch(socket, to: "/browse?r=#{Enum.random(1..1_000_000)}")}
  end

  def handle_event("like", %{"item_id" => id}, socket = %{assigns: %{liked_items: []}}) do
    {:noreply, push_patch(socket, to: ~p"/browse/focus/#{id}", replace: true)}
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
          socket |> assign(liked_items: Enum.concat(liked_items, [doc]))

        idx ->
          socket |> assign(liked_items: List.delete_at(liked_items, idx))
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="browse" class="content-area">
      <.sticky_tools liked_items={@liked_items} show_stickytools?={true}>
        {length(@liked_items)}
      </.sticky_tools>
      <h1 id="browse-header" class="mb-2">{gettext("Browse")}</h1>
      <div :if={!@focused_item} class="text-2xl">
        "Like" a random item below to begin browsing similar items. You can "like" an item to save it for browsing later.
      </div>
      <.display_items {assigns} />
    </div>
    """
  end

  def display_items(assigns) do
    ~H"""
    <div :if={!@focused_item} class="my-5 grid grid-cols-3">
      <button
        class="btn-primary tracking-wider text-xl
          hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
        phx-click="randomize"
      >
        {gettext("Randomize")}
      </button>
    </div>
    <div :if={@focused_item} id="similar-header" class="my-5" phx-hook="ScrollTop">
      <h3>Browsing items similar to: {@focused_item.title}</h3>
    </div>
    <div id="browse-items" class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5">
      <.browse_item :for={item <- @items} item={item} />
    </div>
    """
  end

  def sticky_tools(assigns) do
    ~H"""
    <div
      id="sticky-tools"
      class={["fixed top-20 right-10 z-10 max-w-[100px] flex flex-col gap-2 w-[100px]"]}
    >
      <div :for={item <- @liked_items} class="grid grid-cols-[auto_minmax(0,1fr)] gap-4">
        <BrowseItem.thumb
          phx-click={JS.dispatch("dpulc:scrollTop")}
          thumb={BrowseItem.thumbnail_service_url(item)}
          patch={true}
          link={~p"/browse/focus/#{item.id}"}
        />
      </div>
      <div class="relative inline-flex w-fit flex-col">
        <.link
          phx-click={
            JS.push("randomize")
            |> JS.dispatch("dpulc:scrollTop")
          }
          class="w-full p-4 col-span-1 btn-primary hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
        >
          <.icon name="hero-arrow-path" class="h-6 w-6 icon" />
        </.link>
      </div>
    </div>
    """
  end
end
