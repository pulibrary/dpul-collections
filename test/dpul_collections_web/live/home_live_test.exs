defmodule DpulCollectionsWeb.HomeLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint
  setup do
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

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

  test "recent item blocks", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    {:ok, view, html} = live(conn, "/")

    links =
      html
      |> Floki.parse_document!()
      |> Floki.find(".item-link")
      |> Enum.flat_map(fn a -> Floki.attribute(a, "href") end)

    assert Enum.count(links) == 5
  end

  test "link to browse", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    assert view
           |> element("#browse-callout > a")
           |> render_click() ==
             {:error, {:live_redirect, %{kind: :push, to: "/browse"}}}
  end
end
