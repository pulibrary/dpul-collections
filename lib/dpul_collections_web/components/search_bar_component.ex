defmodule DpulCollectionsWeb.SearchBarComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.SearchComponents
  alias DpulCollectionsWeb.Live.Helpers

  attr :collection_title, :string, default: ""
  attr :search_state, :map, default: %{}

  def render(assigns) do
    ~H"""
    <div>
      <.search_bar
        collection_title={@collection_title}
        search_state={@search_state}
        phx_submit="search"
        phx_target={@myself}
      />
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
    socket = push_navigate(socket, to: Helpers.search_path(params))
    {:noreply, socket}
  end

  # Brand-new search
  def handle_event("search", %{"search" => "all", "q" => q}, socket) do
    params = %{q: q} |> Helpers.clean_params()
    socket = push_navigate(socket, to: Helpers.search_path(params))
    {:noreply, socket}
  end

  # Search within collection
  def handle_event("search", %{"search" => collection_title, "q" => q}, socket) do
    params = %{q: q, filter: %{collection: [collection_title]}} |> Helpers.clean_params()
    socket = push_navigate(socket, to: Helpers.search_path(params))
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
