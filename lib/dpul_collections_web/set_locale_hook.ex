defmodule DpulCollectionsWeb.SetLocaleHook do
  @moduledoc """
  Tells Gettext which locale to use for rendering LiveViews on the front-end.
  Locale should be set in the session in lib/dpul_collections_web/plug/locale_plug.ex
  If no locale is in the session it defaults to English (en).
  """
  import Phoenix.LiveView
  import Phoenix.Component
  import Phoenix.LiveView.Socket
  import Gettext

  def on_mount(:default, _params, session, socket) do
    IO.inspect(socket.assigns, label: "Socket")
    locale = session["locale"] || "en"
    put_locale(locale)
    IO.puts("SetLocaleHook.on_mount called, attaching attach_handle_info")
    IO.puts("LiveView Process: #{inspect(self())}")
    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:live_view_pid, self())
      |> attach_handle_info()

    {:cont, socket}
  end

  defp attach_handle_info(socket) do
    IO.puts("attach_handle_info executed!")
    # Attach an event handler to listen for locale changes
    attach_hook(socket, :set_locale_hook, :handle_event, fn
      "set-locale", %{"locale" => locale}, socket ->
        IO.inspect(socket.assigns, label: "Before")
        IO.puts("handle_info triggered! locale: #{locale}")
        put_locale(DpulCollectionsWeb.Gettext, locale)
        
        socket = assign(socket, :locale, locale)
        IO.inspect(socket.assigns, label: "After")

        {:halt, socket}

      _, _, socket ->
        IO.puts("Received unexpected message in handle_info")
        {:cont, socket}
    end)
  end

  # def on_mount(:default, _params, %{"locale" => locale}, socket) do
  #   Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)
  #   {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  # end

  # def on_mount(:default, _params, _session, socket) do
  #   # Fallback when "locale" is not in session
  #   default_locale = "en"
  #   Gettext.put_locale(DpulCollectionsWeb.Gettext, default_locale)
  #   {:cont, Phoenix.Component.assign(socket, :locale, default_locale)}
  # end
  # def on_mount(:default, _params, session, socket) do
  #   locale = Map.get(session, "locale", "en")
  #   Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)

  #   {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  # end
end
