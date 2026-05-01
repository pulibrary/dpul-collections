defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  attr :collection_title, :string, default: ""
  attr :search_state, :map, default: %{}

  def render(assigns) do
    ~H"""
    <div class="subnav-bar cover-with-pane">
      <div class="search-container min-h-[48px] bg-search">
        <form
          id="search-form"
          class="grow group w-full h-full"
          phx-submit="search"
          phx-target={@myself}
        >
          <.input
            :if={Enum.any?(@search_state)}
            type="hidden"
            name="search_state"
            value={JSON.encode!(@search_state)}
          />
          <div
            class={[
              "grid md:grid-rows-1 md:grid-cols-[1fr_min-content] items-stretch w-full h-full",
              String.length(@collection_title) > 0 && "grid-rows-2 grid-cols-1",
              String.length(@collection_title) > 0 || "grid-rows-1 grid-cols-[1fr_min-content]"
            ]}
            role="search"
          >
            <div class="subnav-l-padding flex items-center grow">
              <span class="flex-none">
                <.icon name="hero-magnifying-glass" class="h-8 w-8 icon" />
              </span>
              <label for="q" class="sr-only">{gettext("Search")}</label>
              <input
                class="m-2 px-1 py-0 grow w-full h-full placeholder:text-dark-text/40 bg-transparent border-none placeholder:text-xl text-xl placeholder:font-bold"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Search")}
                dir="auto"
              />
            </div>

            <div class={[
              "subnav-buttons flex items-stretch justify-items-stretch space-x-1 text-sm md:text-base md:w-auto",
              String.length(@collection_title) > 0 && "w-[calc(100%+40px)]"
            ]}>
              <.primary_button
                :if={String.length(@collection_title) > 0}
                id="collection-search-button"
                type="submit"
                name="search"
                value={@collection_title}
                class="grow max-md:subnav-diagonal-left md:subnav-diagonal-middle h-[48px]"
              >
                {gettext("In this Collection")}
                <.icon name="hero-arrow-turn-down-left" class="h-4/7 ml-1 hidden md:inline" />
              </.primary_button>

              <.primary_button
                id="search-button"
                type="submit"
                name="search"
                value="all"
                class={[
                  "grow subnav-diagonal-right h-[48px]",
                  String.length(@collection_title) > 0 && "subnav-diagonal-right-pair",
                  String.length(@collection_title) > 0 || "subnav-r-padding"
                ]}
              >
                {search_label(@collection_title)}
              </.primary_button>
            </div>
          </div>
        </form>
      </div>
      <.content_separator />
    </div>
    """
  end

  # Search from results page
  def handle_event(
        "search",
        %{"search_state" => search_state, "search" => "all", "q" => q},
        socket
      ) do
    filters =
      search_state
      |> JSON.decode!()
      |> Map.take(["filter", "sort_by"])

    params = %{q: q} |> Helpers.clean_params() |> Map.merge(filters)
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  # Brand-new search
  def handle_event("search", %{"search" => "all", "q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  # Search within collection
  def handle_event("search", %{"search" => collection_title, "q" => q}, socket) do
    params = %{q: q, filter: %{collection: [collection_title]}} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

  # We're not on a collection page
  def search_label("") do
    gettext("Search")
  end

  def search_label(_) do
    gettext("Search all")
  end
end
