# Credit: https://github.com/goofansu/locale_plug
defmodule DpulCollectionsWeb.ShowImagesPlugTest do
  use ExUnit.Case, async: true
  use DpulCollectionsWeb.ConnCase

  test "setting a list of uuids via cookie is valid", %{conn: conn} do
    conn =
      conn
      |> put_resp_cookie(
        "showImages1",
        "d4292e58-25d7-4247-bf92-0a5e24ec75d1,eecc7710-1243-45e0-9efd-f61b63ad34ef"
      )

    conn = get(conn, "/")

    assert Plug.Conn.get_session(conn, :show_images) == [
             "d4292e58-25d7-4247-bf92-0a5e24ec75d1",
             "eecc7710-1243-45e0-9efd-f61b63ad34ef"
           ]
  end

  test "setting a single uuid via cookie is valid", %{conn: conn} do
    conn =
      conn
      |> put_resp_cookie("showImages1", "d4292e58-25d7-4247-bf92-0a5e24ec75d1")

    conn = get(conn, "/")
    assert Plug.Conn.get_session(conn, :show_images) == ["d4292e58-25d7-4247-bf92-0a5e24ec75d1"]
  end

  test "setting something nefarious via cookie is invalid", %{conn: conn} do
    conn =
      conn
      |> put_resp_cookie("showImages1", "exec(mess_stuff_up_yeah)")

    conn = get(conn, "/")
    assert Plug.Conn.get_session(conn, :show_images) == nil
  end
end
