defmodule DpulCollectionsWeb.UserSets.AddToSetComponent do
  use DpulCollectionsWeb, :live_component
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def render(assigns) do
    ~H"""
    """
  end

  attr :item_id, :string, required: true

  def add_button(assigns) do
    ~H"""
    <button class="flex flex-col">
      Save
    </button>
    """
  end
end
