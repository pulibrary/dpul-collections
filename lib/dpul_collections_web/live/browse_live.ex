defmodule DpulCollectionsWeb.BrowseLive do
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
        recommended_items: [],
        show_stickytools?: false,
        page_title: "Browse - Digital Collections"
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

  def handle_event("randomize_recommended", _map, socket) do
    socket =
      socket |> assign(recommended_items: generate_recommendations(socket.assigns.liked_items))

    {:noreply, socket}
  end

  def handle_event(
        "like",
        %{"item_id" => id, "browse_id" => browse_id},
        socket = %{
          assigns: %{items: items, liked_items: liked_items, recommended_items: recommended_items}
        }
      ) do
    doc = (items ++ recommended_items) |> Enum.find(fn item -> item.id == id end)

    socket =
      case Enum.find_index(liked_items, fn liked_item -> doc.id == liked_item.id end) do
        nil ->
          socket |> assign(liked_items: Enum.concat(liked_items, [doc]))

        idx ->
          socket |> assign(liked_items: List.delete_at(liked_items, idx))
      end

    socket =
      case browse_id do
        "recommended-items" ->
          socket

        _ ->
          socket
          |> assign(recommended_items: generate_recommendations(socket.assigns.liked_items))
      end

    {:noreply, socket}
  end

  def handle_event("show_stickytools", _params, socket) do
    {:noreply, assign(socket, :show_stickytools?, true)}
  end

  def handle_event("hide_stickytools", _params, socket) do
    {:noreply, assign(socket, :show_stickytools?, false)}
  end

  def generate_recommendations([]), do: []

  def generate_recommendations(liked_items) when is_list(liked_items) do
    Solr.random_recommended_from_items(liked_items)["docs"]
    |> Enum.map(&Item.from_solr(&1))
  end

  def render(assigns) do
    ~H"""
    <div class="content-area">
      <h1 class="mb-2">{gettext("Browse")}</h1>
      {# coveralls-ignore-start}
      <.tabs id="browse-tabs" class="border-b-4 border-accent">
        {# coveralls-ignore-stop}
        <:tab>
          <.icon name="hero-heart-solid" class="bg-accent" />{gettext("My Liked Items")} ({length(
            @liked_items
          )})
        </:tab>
        <:tab>{gettext("Recommended Items")}</:tab>
        <:tab active={true}>{gettext("Random Items")}</:tab>
        <:panel>
          <.liked_items {assigns} />
        </:panel>
        <:panel>
          <.recommendations {assigns} />
        </:panel>
        <:panel>
          <.random_items {assigns} />
        </:panel>
      </.tabs>
    </div>
    """
  end

  def recommendations(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div class="text-xl">
        {gettext("Recommendations are generated randomly based on items you've liked while browsing.")}
      </div>
      <div class="grid grid-cols-3">
        <button
          class="btn-primary tracking-wider text-xl
              hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
          phx-click="randomize_recommended"
        >
          {gettext("Randomize")}
        </button>
      </div>

      <div
        id="recommended-items"
        class="grid grid-cols-[repeat(auto-fit,minmax(300px,_1fr))] gap-6 pt-5"
      >
        <.browse_item :for={item <- @recommended_items} id="recommended-items" item={item} />
      </div>
    </div>
    """
  end

  def liked_items(assigns) do
    ~H"""
    <div id="liked-items" class="flex flex-col gap-4">
      <h2>{gettext("Liked Items")}</h2>
      <div>
        {gettext("Liked items can be used to make recommendations based on the items you have liked.")}
      </div>
      <div class="flex gap-4">
        <.primary_button class="px-4">
          <.icon name="hero-check-solid" />{gettext("Check all items")}
        </.primary_button>
        <.primary_button class="px-4">
          <.icon name="hero-trash" />{gettext("Remove checked items")}
        </.primary_button>
      </div>
      <div class="grid grid-flow-row auto-rows-max gap-8">
        <div :for={item <- @liked_items} class="grid grid-cols-[auto_minmax(0,1fr)] gap-4">
          <hr class="mb-8 col-span-2" />
          <div>
            <input type="checkbox" />
          </div>
          <div class="flex gap-4 flex-col">
            <DpulCollectionsWeb.SearchLive.search_item search_state={%{}} item={item} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  def random_items(assigns) do
    ~H"""
    <div class="my-5 grid grid-cols-3" id="browse-header" phx-hook="ToolbarHook">
      <.sticky_tools show_stickytools?={@show_stickytools?}>{length(@liked_items)}</.sticky_tools>
      <button
        class="btn-primary tracking-wider text-xl
          hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
        phx-click="randomize"
      >
        {gettext("Randomize")}
      </button>
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
      class={["fixed top-20 right-10 z-10", (@show_stickytools? && "visible") || "invisible"]}
    >
      <div class="relative inline-flex w-fit flex-col">
        <div class="absolute bottom-auto left-auto right-0 top-0 z-10 inline-block -translate-y-1/2 translate-x-2/4 rotate-0 skew-x-0 skew-y-0 scale-x-100 scale-y-100 whitespace-nowrap rounded-full bg-red-600 px-1.5 py-1 text-center align-baseline text-xs font-bold leading-none text-white">
          {render_slot(@inner_block)}
        </div>
        <.link id="liked-button" phx-click={JS.exec("phx-show-tab", to: "#browse-tabs-tab-header-1")}>
          <span class="cursor-pointer mb-2 grid grid-cols-1 grid-rows-1 rounded-sm bg-primary hover:bg-sage-200 px-6 py-2.5 text-xs font-medium uppercase leading-normal text-white shadow-md transition duration-150 ease-in-out hover:shadow-lg focus:shadow-lg focus:outline-hidden focus:ring-0 active:shadow-lg text-accent">
            <.icon name="hero-heart-solid" class="row-[1] col-[1] h-6 w-6 icon bg-accent" />
            <.icon name="hero-heart" class="row-[1] col-[1] h-6 w-6 icon bg-dark-text" />
          </span>
        </.link>
        <a href="#browse-items">
          <button
            class="w-full col-span-1 btn-primary hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
            phx-click="randomize"
          >
            <.icon name="hero-arrow-path" class="h-6 w-6 icon" />
          </button>
        </a>
      </div>
    </div>
    """
  end
end
