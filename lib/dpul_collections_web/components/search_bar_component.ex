defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  def render(assigns) do
    ~H"""
    <div class="search-bar cover-with-pane">
      <div class="search-browse-container min-h-10 flex flex-wrap bg-search">
        <div class="search-box header-x-padding grow">
          <form id="search-form" class="group w-full h-full" phx-submit="search" phx-target={@myself}>
            <div class="flex items-center w-full h-full space-x-2" role="search">
              <span class="flex-none">
                <.icon name="hero-magnifying-glass" class="h-8 w-8 icon" />
              </span>
              <label for="q" class="sr-only">{gettext("Search")}</label>
              <input
                class="m-2 px-1 py-0 grow h-full placeholder:text-dark-text/40 bg-transparent border-none placeholder:text-xl text-xl placeholder:font-bold w-full"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Search")}
                dir="auto"
              />
              <.primary_button
                id="collection-search-button"
                type="submit"
                class="btn-primary px-4 h-8 flex-none"
              >
                {gettext("Search in this Collection")}<.icon name="hero-arrow-turn-down-left" class="h-6/10 ml-1"/>
              </.primary_button>
              <.primary_button
                id="search-button"
                type="submit"
                class="btn-primary px-4 h-8 flex-none mr-2px"
              >
                {gettext("Search all")}
              </.primary_button>
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
