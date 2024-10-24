defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup_all do
    Solr.add(SolrTestSupport.mock_solr_documents())
    Solr.commit()
    on_exit(fn -> Solr.delete_all() end)
  end

  test "GET /search", %{conn: conn} do
    conn = get(conn, ~p"/search")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"underline text-lg\">Document-1</div>"
    assert response =~ "<div class=\"underline text-lg\">Document-2</div>"
  end

  test "GET /search with blank q parameter", %{conn: conn} do
    conn = get(conn, ~p"/search?q=")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"underline text-lg\">Document-1</div>"
    assert response =~ "<div class=\"underline text-lg\">Document-2</div>"
  end

  test "searching filters results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search?")

    response =
      view
      |> element("#search-form")
      |> render_submit(%{"q" => "Document-2"})

    assert response =~ "<div class=\"underline text-lg\">Document-2</div>"
    assert !(response =~ "<div class=\"underline text-lg\">Document-1</div>")
  end

  test "items can be sorted by date, ascending and descending", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    response = render_click(view, "sort", %{"sort-by" => "date_asc"})
    assert response =~ "<div class=\"underline text-lg\">Document-100</div>"
    assert !(response =~ "<div class=\"underline text-lg\">Document-1</div>")

    response = render_click(view, "sort", %{"sort-by" => "date_desc"})
    assert response =~ "<div class=\"underline text-lg\">Document-1</div>"
    assert !(response =~ "<div class=\"underline text-lg\">Document-100</div>")
  end

  test "items can be filtered by date range", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    response =
      view
      |> element("#search-form")
      |> render_submit(%{"date-from" => "1925", "date-to" => "1926"})

    assert !(response =~ "<div class=\"underline text-lg\">Document-98</div>")
    assert response =~ "<div class=\"underline text-lg\">Document-99</div>"
    assert response =~ "<div class=\"underline text-lg\">Document-100</div>"
  end

  test "paginator works as expected", %{conn: conn} do
    # Check that the previous link is hidden on the first page
    {:ok, view, _html} = live(conn, ~p"/search?page=1")
    assert !(view |> element("#paginator-previous") |> has_element?())
    assert view |> element("#paginator-next") |> has_element?()

    # Check that the previous and next links are displayed and work as expected
    {:ok, view, _html} = live(conn, ~p"/search?page=5")
    assert(view |> element(".paginator > a.active", ~r(5)) |> has_element?())

    assert view
           |> element("#paginator-previous")
           |> render_click() =~ "<div class=\"underline text-lg\">Document-40</div>"

    assert view
           |> element("#paginator-next")
           |> render_click() =~ "<div class=\"underline text-lg\">Document-50</div>"

    # Check that the next link is hidden on the last page
    {:ok, view, _html} = live(conn, ~p"/search?page=10")
    assert view |> element("#paginator-previous") |> has_element?()
    assert !(view |> element("#paginator-next") |> has_element?())

    # Check that clicking the "..." paginator link
    # does not change the rendered page
    assert view
           |> element("a", "...")
           |> render_click() =~ "<div class=\"underline text-lg\">Document-100</div>"
  end
end
