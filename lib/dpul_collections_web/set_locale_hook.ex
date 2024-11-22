defmodule DpulCollectionsWeb.SetLocaleHook do
  @moduledoc """
  Tells Gettext which locale to use for rendering LiveViews on the front-end.
  Locale should be set in the session in lib/dpul_collections_web/plug/locale_plug.ex
  If no locale is in the session it defaults to English (en).
  """

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
