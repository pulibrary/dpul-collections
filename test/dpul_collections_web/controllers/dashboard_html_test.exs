defmodule DpulCollectionsWeb.DashboardHtmlTest do
  use DpulCollectionsWeb.ConnCase

  describe "index" do
    test "requires basic auth", %{conn: conn} do
      no_auth_conn = get(conn, ~p"/dev/dashboard")
      assert no_auth_conn.status == 401

      bad_auth_conn =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("admin:bad"))
        |> get(~p"/dev/dashboard")

      assert bad_auth_conn.status == 401

      auth_conn =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("admin:test"))
        |> get(~p"/dev/dashboard")

      assert html_response(auth_conn, 302)
    end
  end
end
