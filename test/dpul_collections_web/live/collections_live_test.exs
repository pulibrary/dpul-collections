defmodule DpulCollectionsWeb.CollectionsLiveTest do
  use DpulCollectionsWeb.ConnCase
  @endpoint DpulCollectionsWeb.Endpoint

  test "/collections/{:slug} 404s with a bad slug", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/collections/not-a-real-slug")
    end
  end
end
