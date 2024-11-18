defmodule DpulCollectionsWeb.SetLocaleHook do
  import Phoenix.LiveView

  def on_mount(:default, _params, %{"locale" => locale}, socket) do
    Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end
end
