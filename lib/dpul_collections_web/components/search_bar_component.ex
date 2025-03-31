defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  import DpulCollectionsWeb.Gettext
  alias DpulCollectionsWeb.Live.Helpers

  def render(assigns) do
    ~H"""
    <div class="search-bar grid grid-flow-row auto-rows-max gap-20">
      <form id="search-form" phx-submit="search" phx-target={@myself}>
        <div class="grid grid-cols-4">
          <label for="q" class="sr-only">Search</label>
          <input class="col-span-4 md:col-span-3" type="text" id="q" name="q" />
          <button class="col-span-4 md:col-span-1 btn-primary" type="submit">
            {gettext("Search")}
          </button>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: ~p"/search?#{params}")
    {:noreply, socket}
  end
end
