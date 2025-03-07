defmodule DpulCollectionsWeb.HomeLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint

  test "GET /", %{conn: conn} do
    count = DpulCollections.Solr.document_count()
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "#{count} Ephemera items"
  end

  test "search form redirect", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    assert view
           |> element("form")
           |> render_submit(%{"q" => "cats"}) ==
             {:error, {:live_redirect, %{kind: :push, to: "/search?q=cats"}}}
  end

  test "link to browse", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    assert view
           |> element("#browse-callout > a")
           |> render_click() ==
             {:error, {:live_redirect, %{kind: :push, to: "/browse"}}}
  end
end
