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
              <span><.icon name="hero-magnifying-glass" class="h-6 w-6 icon" /></span>
              <label for="q" class="sr-only">{gettext("Search")}</label>
              <input
                class="h-full w-full bg-transparent border-none placeholder:text-dark-blue placeholder:text-xl placeholder:font-semibold"
                type="text"
                id="q"
                name="q"
                placeholder={gettext("Search")}
              />
              <button class="btn-secondary px-4 h-8" type="submit">
                {gettext("Search")}
              </button>
            </div>
          </form>
        </div>

        <div class="browse-link flex items-center header-e-padding bg-cloud">
          <div class="w-full text-right heading text-xl">
            <span><.icon name="hero-square-3-stack-3d" class="h-6 w-6 icon" /></span>
            <.link navigate={~p"/browse"}>
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
