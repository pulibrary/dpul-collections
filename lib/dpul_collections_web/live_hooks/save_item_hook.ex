defmodule DpulCollectionsWeb.LiveHooks.SaveItemHook do
  @moduledoc """
  Allows all live_views to handle the "save_item" param, allowing saving an item from any page to a user set.
  """
  alias DpulCollectionsWeb.UserSets.AddToSetComponent
  import Phoenix.LiveView, only: [attach_hook: 4, send_update: 2]

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      # When "save_item" is in the params tell the AddToSetComponent.
      |> attach_hook(:handle_save_item, :handle_params, &handle_save_item/3)

    {:cont, socket}
  end

  defp handle_save_item(%{"save_item" => save_item}, _uri, socket) do
    send_update(AddToSetComponent, id: "user_set_form", item_id: save_item)
    {:cont, socket}
  end

  defp handle_save_item(_params, _uri, socket) do
    {:cont, socket}
  end
end
