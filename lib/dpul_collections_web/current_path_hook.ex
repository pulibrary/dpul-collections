defmodule DpulCollectionsWeb.CurrentPathHook do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  # Whenever the path gets updated, store it in assigns.
  # Pulled from https://elixirforum.com/t/how-can-i-obtain-the-current-url-to-pass-to-a-functional-component-from-the-app-html-heex-layout-when-rendering-liveviews/59053/8
  def on_mount(:global, _params, _session, socket) do
    socket =
      attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)

    {:cont, socket}
  end

  defp assign_current_path(_params, uri, socket) do
    uri = URI.parse(uri)
    path = "#{uri.path}?#{uri.query}"

    {:cont, assign(socket, :current_path, path)}
  end
end
