# Credit: https://github.com/goofansu/locale_plug
defmodule DpulCollectionsWeb.LocalePlugTest do
  use ExUnit.Case, async: true
  use DpulCollectionsWeb.ConnCase

  @default_locale "en"

  setup do
    # Reset locale before each test to avoid interference
    Gettext.put_locale(DpulCollectionsWeb.Gettext, @default_locale)
    :ok
  end

  test "set supported locale from params", %{conn: conn} do
    conn = get(conn, "/?locale=es")

    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == "es"
    assert conn.resp_cookies["locale"][:value] == "es"
    assert get_resp_header(conn, "content-language") == ["es"]
  end

  test "set supported locale from params with partial match", %{conn: conn} do
    conn = get(conn, "/?locale=es_ES")

    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == "es"
    assert conn.resp_cookies["locale"][:value] == "es"
    assert get_resp_header(conn, "content-language") == ["es"]
  end

  test "set unsupported locale from params", %{conn: conn} do
    conn = get(conn, "/?locale=zh_CN")

    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == Gettext.get_locale()
    assert conn.resp_cookies["locale"] == nil
    assert get_resp_header(conn, "content-language") == []
  end

  test "set locale from headers", %{conn: conn} do
    conn =
      put_req_header(conn, "accept-language", "zh-CN,es;q=0.9,en;q=0.8,zh;q=0.7")
      |> get("/")

    assert Gettext.get_locale(DpulCollectionsWeb.Gettext) == "es"
    assert conn.resp_cookies["locale"][:value] == "es"
    assert get_resp_header(conn, "content-language") == ["es"]
  end
end
