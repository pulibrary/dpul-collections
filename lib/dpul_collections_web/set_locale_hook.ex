defmodule DpulCollectionsWeb.SetLocaleHook do
  def on_mount(:default, _params, %{"locale" => locale}, socket) do
    Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  def on_mount(:default, _params, _session, socket) do
    # Fallback when "locale" is not in session
    default_locale = "en"
    Gettext.put_locale(DpulCollectionsWeb.Gettext, default_locale)
    {:cont, Phoenix.Component.assign(socket, :locale, default_locale)}
  end
end
