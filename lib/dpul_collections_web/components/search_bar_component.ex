defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  import DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  def render(assigns) do
    ~H"""
    <div class="search-bar">
      <div class="search-browse-container min-h-14 flex justify-between bg-sage">
        <div class="search-box header-x-padding w-2/3">
          <form id="search-form" class="w-full h-full" phx-submit="search" phx-target={@myself}>
            <div class="flex items-center justify-between h-full text-dark-blue">
              <span><.icon name="hero-magnifying-glass" class="h-10 w-10 icon" /></span>
              <label for="q" class="sr-only">{gettext("Search")}</label>
              <input
                class="m-2 p-1 h-full w-full bg-transparent border-none placeholder:text-dark-sage placeholder:text-2xl placeholder:font-bold"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Search")}
              />
              <button id="search-button" type="submit" class="btn-secondary px-4 h-8 invisible">
                {gettext("Search")}
              </button>
            </div>
          </form>
        </div>

        <div class="browse-link flex items-center header-e-padding bg-cloud">
          <div class="w-full text-right heading text-xl font-bold">
            <span><.icon name="hero-square-3-stack-3d" class="p-1 h-10 w-10 icon" /></span>
            <.link navigate={~p"/browse"} class="pl-2">
              {gettext("Browse all items")}
            </.link>
          </div>
        </div>
      </div>
      <hr class="h-1 border-0 bg-rust" />
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
