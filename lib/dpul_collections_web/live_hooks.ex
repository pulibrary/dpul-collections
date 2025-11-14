defmodule DpulCollectionsWeb.LiveHooks do
  alias DpulCollectionsWeb.UserSets.AddToSetComponent
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, send_update: 2]

  # Whenever the path gets updated, store it in assigns.
  # Pulled from https://elixirforum.com/t/how-can-i-obtain-the-current-url-to-pass-to-a-functional-component-from-the-app-html-heex-layout-when-rendering-liveviews/59053/8
  def on_mount(:global, _params, _session, socket) do
    socket =
      socket
      # Assign current_path to everything.
      |> attach_hook(:assign_current_path, :handle_params, &assign_current_path/3)
      # When "save_item" is in the params tell the AddToSetComponent.
      |> attach_hook(:handle_save_item, :handle_params, &handle_save_item/3)

    {:cont, socket}
  end

  defp assign_current_path(_params, uri, socket) do
    uri = URI.parse(uri)
    path = "#{uri.path}?#{uri.query}"

    {:cont, assign(socket, :current_path, path)}
  end

  defp handle_save_item(%{"save_item" => save_item}, _uri, socket) do
    send_update(AddToSetComponent, id: "user_set_form", item_id: save_item)
    {:cont, socket}
  end

  defp handle_save_item(_params, _uri, socket) do
    {:cont, socket}
  end
end
