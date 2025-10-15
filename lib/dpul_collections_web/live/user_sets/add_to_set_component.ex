defmodule DpulCollectionsWeb.UserSets.AddToSetComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  attr :item_id, :string, default: nil

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id="add-set-modal"
        label="Save to Set"
        open={@item_id != nil}
      >
        <div id="add-set-modal-content" class="mt-4">
          Sup - {@item_id}
        </div>
      </.modal>
    </div>
    """
  end

  def handle_event("open_modal", %{"item_id" => item_id}, socket) do
    {:noreply,
     socket |> assign(:item_id, item_id) |> push_event("dcjs-open", %{id: "add-set-modal"})}
  end

  attr :item_id, :string, required: true

  def add_button(assigns) do
    ~H"""
    <.card_button
      icon="hero-folder-plus"
      label={gettext("Save")}
      phx-click="open_modal"
      phx-value-item_id={@item_id}
      phx-target="#add-set-modal"
    />
    """
  end
end
