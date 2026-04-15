defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  attr :collection_title, :string, default: ""
  attr :search_state, :map, default: %{}

  def render(assigns) do
    ~H"""
    <div class="search-bar cover-with-pane">
      <div class="search-browse-container min-h-10 flex flex-wrap bg-search">
        <div class="search-box header-x-padding grow w-full">
          <form id="search-form" class="group w-full h-full" phx-submit="search" phx-target={@myself}>

            <.input
              :if={Enum.any?(@search_state)}
              type="hidden"
              name="applied_filters"
              value={JSON.encode!(@search_state.filter)} />

            <.input
              :if={Enum.any?(@search_state)}
              type="hidden"
              name="search_state"
              value={JSON.encode!(@search_state)} />
            <div
              class={[
                "flex items-center w-full h-full",
                String.length(@collection_title) > 0 && "flex-wrap"
              ]}
              role="search"
            >
              <div class="flex items-center grow">
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
                "flex items-stretch space-x-2 my-2 text-sm md:text-md md:w-auto",
                String.length(@collection_title) > 0 && "w-full"
              ]}>
                <.primary_button
                  :if={String.length(@collection_title) > 0}
                  id="collection-search-button"
                  type="submit"
                  name="search"
                  value={@collection_title}
                  class="btn-primary px-4 h-8 grow"
                >
                  {gettext("Search in this Collection")}
                  <.icon name="hero-arrow-turn-down-left" class="h-4/7 ml-1 hidden md:inline" />
                </.primary_button>

                <.primary_button
                  id="search-button"
                  type="submit"
                  name="search"
                  value="all"
                  class="btn-primary px-4 h-8 mr-2px grow"
                >
                  {search_label(@collection_title)}
                </.primary_button>
              </div>
            </div>
          </form>
        </div>
      </div>
      <.content_separator />
    </div>
    """
  end

  def handle_event("search", params = %{"search" => "all", "q" => q}, socket) do
    filters = %{filter: params["applied_filters"] |> JSON.decode!()}
    params = %{q: q} |> Helpers.clean_params() |> Map.merge(filters)
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end

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
