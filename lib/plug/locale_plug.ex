defmodule DpulCollectionsWeb.LocalePlug do
  import Plug.Conn
  import Phoenix.Controller

  def init(default), do: default

  def call(conn, _opts) do
    locale = get_locale(conn)
    Gettext.put_locale(DpulCollectionsWeb.Gettext, locale)
    conn |> put_session(:locale, locale) |> add_locale_to_url(locale)
  end

  defp get_locale(conn) do
    # Default to English if no locale is found
    conn.params["locale"] ||
      get_session(conn, :locale) ||
      "en"
  end

  defp add_locale_to_url(conn, locale) do
    if conn.params["locale"] do
      # Locale already in the URL, no need to modify
      conn
    else
      # Redirect to the same path with the locale added as a query param
      path_with_locale = "#{conn.request_path}?locale=#{locale}"
      conn |> redirect(to: path_with_locale) |> halt()
    end
  end
end
