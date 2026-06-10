defmodule DpulCollectionsWeb.LiveDashboard.IndexValidationPage do
  alias DpulCollections.IndexValidator
  use Phoenix.LiveDashboard.PageBuilder, refresher?: false

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
        <.card_title title={validator.collection.title} />

        <.fields_card
          inner_title="Digital Collections Count"
          fields={[
            count: validator.dc_count
          ]}
        />
        <div :if={length(validator.missing_items) > 0}>
          <h6>Missing items (In Figgy, but not DC)</h6>
          <ul>
            <li :for={id <- validator.missing_items}>
              <.link href={"https://figgy.princeton.edu/catalog/#{id}"}>{id}</.link>
            </li>
          </ul>
        </div>
      </:col>
    </.row>
    """
  end
end
