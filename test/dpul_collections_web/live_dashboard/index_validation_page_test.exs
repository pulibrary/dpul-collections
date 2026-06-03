defmodule DpulCollectionsWeb.LiveDashboard.IndexValidationPageTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint

  test "GET /dev/dashboard/index_validation", %{conn: conn} do
    {:ok, view, html} =
      conn
      |> put_req_header("authorization", "Basic " <> Base.encode64("admin:test"))
      |> get(~p"/dev/dashboard/index_validation")
      |> live
  end
end
