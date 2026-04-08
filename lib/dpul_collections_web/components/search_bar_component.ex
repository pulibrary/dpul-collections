defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  def render(assigns) do
    ~H"""
    <div class="search-bar cover-with-pane">
      <div class="search-browse-container min-h-10 flex flex-wrap bg-search">
        <div class="search-box header-x-padding grow w-full">
          <form id="search-form" class="group w-full h-full" phx-submit="search" phx-target={@myself}>
            <div class="flex flex-wrap items-center w-full h-full" role="search">
              <div class="flex items-center w-full">
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

              <div class="flex items-stretch space-x-2 my-2 text-sm md:text-md w-full">
              <.primary_button
                id="collection-search-button"
                type="submit"
                class="btn-primary px-4 h-8 flex-none"
              >
                {gettext("Search in this Collection")}<span class="hidden md:inline-flex"><.icon name="hero-arrow-turn-down-left" class="invisible md:visible h-6/10 ml-1"/></span>
              </.primary_button>

              <.primary_button
                id="search-button"
                type="submit"
                class="btn-primary px-4 h-8 flex-none mr-2px"
              >
                {gettext("Search all")}
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

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
