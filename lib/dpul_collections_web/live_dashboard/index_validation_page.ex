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
        validators: IndexValidator.all_collections()
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.row :for={validator <- @validators}>
      <:col>
        <card_title>{validator.collection.title}</card_title>

        <.fields_card
          inner_title="Digital Collections Count"
          fields={[
            count: validator.dc_count
          ]}
        />
      </:col>
    </.row>
    """
  end
end
