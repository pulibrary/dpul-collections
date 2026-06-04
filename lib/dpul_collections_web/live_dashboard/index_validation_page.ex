defmodule DpulCollectionsWeb.LiveDashboard.IndexValidationPage do
  alias DpulCollections.IndexValidator
  use Phoenix.LiveDashboard.PageBuilder

  @impl true
  def menu_link(_, _) do
    {:ok, "Index Validation"}
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        all_collections: IndexValidator.all_collections()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.row :for={collection <- @all_collections}>
      <:col>
        <card_title>{collection.title}</card_title>
      </:col>
    </.row>
    """
  end
end
