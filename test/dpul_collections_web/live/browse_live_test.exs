defmodule DpulCollectionsWeb.BrowseLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/browse")
    assert html_response(conn, 200)
  end
end
