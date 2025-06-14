defmodule DpulCollectionsWeb.BrowseLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(items: [], pinned_items: [], show_stickytools?: false)

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

  def handle_event("show_stickytools", _params, socket) do
    {:noreply, assign(socket, :show_stickytools?, true)}
  end

  def handle_event("hide_stickytools", _params, socket) do
    {:noreply, assign(socket, :show_stickytools?, false)}
  end

  def render(assigns) do
    ~H"""
    <div class="content-area">
      <.sticky_tools show_stickytools?={@show_stickytools?}>{length(@pinned_items)}</.sticky_tools>
      <h1 class="col-span-3">{gettext("Pinned")}</h1>
      <div id="pinned-items" class="my-5 grid grid-flow-row auto-rows-max gap-10 grid-cols-1">
        <div class="grid grid-flow-row auto-rows-max gap-8">
          <DpulCollectionsWeb.SearchLive.search_item
            :for={item <- @pinned_items}
            search_state={%{}}
            item={item}
          />
        </div>
      </div>
      <div
        class="my-5 grid grid-flow-row auto-rows-max gap-10 grid-cols-4"
        id="browse-header"
        phx-hook="ToolbarHook"
      >
        <h1 class="col-span-3">{gettext("Browse")}</h1>
        <button
          class="col-span-1 btn-primary tracking-wider text-xl
          hover:bg-sage-200 transform transition duration-5 active:shadow-none active:-translate-x-1 active:translate-y-1"
          phx-click="randomize"
        >
          {gettext("Randomize")}
        </button>
      </div>
      <div class="grid grid-cols-3 gap-6 pt-5">
        <.browse_item :for={item <- @items} item={item} />
      </div>
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
        <a href="#pinned-items">
          <span class="cursor-pointer mb-2 flex rounded-sm bg-[#3eb991] px-6 py-2.5 text-xs font-medium uppercase leading-normal text-white shadow-md transition duration-150 ease-in-out hover:shadow-lg focus:shadow-lg focus:outline-hidden focus:ring-0 active:shadow-lg">
            <.icon name="hero-archive-box-solid" class="h-6 w-6 icon" />
          </span>
        </a>
        <a href="#browse-header">
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
