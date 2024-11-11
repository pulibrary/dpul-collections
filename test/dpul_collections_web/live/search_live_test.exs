defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup_all do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "GET /search", %{conn: conn} do
    conn = get(conn, ~p"/search")

    document =
      html_response(conn, 200)
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()
  end

  test "GET /search with blank q parameter", %{conn: conn} do
    conn = get(conn, ~p"/search?q=")

    document =
      html_response(conn, 200) |> Floki.parse_document() |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()
  end

  test "GET /search renders thumbnails for each resource", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search?")

    assert view
           |> has_element?(
             "#item-1 img[src='https://example.com/iiif/2/image1/square/350,350/0/default.jpg']"
           )

    assert view
           |> has_element?(
             "#item-1 img[src='https://example.com/iiif/2/image2/square/350,350/0/default.jpg']"
           )

    assert view
           |> has_element?(
             "#item-2 img[src='https://example.com/iiif/2/image1/square/350,350/0/default.jpg']"
           )

    assert view
           |> has_element?(
             "#item-2 img[src='https://example.com/iiif/2/image2/square/350,350/0/default.jpg']"
           )
  end

  test "searching filters results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search?")

    document =
      view
      |> element("#search-form")
      |> render_submit(%{"q" => "Document-2"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()
  end

  test "items can be sorted by date, ascending and descending", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    document =
      view
      |> render_click("sort", %{"sort-by" => "date_asc"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()

    document =
      view
      |> render_click("sort", %{"sort-by" => "date_desc"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.empty?()
  end

  test "items can be filtered by date range", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    document =
      view
      |> element("#search-form")
      |> render_submit(%{"date-from" => "1925", "date-to" => "1926"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find(~s{a[href="/i/document99/item/99"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document98/item/98"]})
           |> Enum.empty?()
  end

  test "paginator works as expected", %{conn: conn} do
    # Check that the previous link is hidden on the first page
    {:ok, view, _html} = live(conn, ~p"/search?page=1")
    assert !(view |> has_element?("#paginator-previous"))
    assert view |> has_element?("#paginator-next")

    # Check that the previous and next links are displayed and work as expected
    {:ok, view, _html} = live(conn, ~p"/search?page=5")
    assert(view |> element(".paginator > a.active", ~r(5)) |> has_element?())

    assert view
           |> element("#paginator-previous")
           |> render_click()
           |> follow_redirect(conn)
           |> elem(2)
           |> Floki.parse_document()
           |> elem(1)
           |> Floki.find(~s{a[href="/i/document40/item/40"]})
           |> Enum.any?()

    {:ok, view, _html} = live(conn, ~p"/search?page=4")

    assert view
           |> element("#paginator-next")
           |> render_click()
           |> follow_redirect(conn)
           |> elem(2)
           |> Floki.parse_document()
           |> elem(1)
           |> Floki.find(~s{a[href="/i/document50/item/50"]})
           |> Enum.any?()

    # Check that the next link is hidden on the last page
    {:ok, view, _html} = live(conn, ~p"/search?page=10")
    assert view |> has_element?("#paginator-previous")
    assert !(view |> has_element?("#paginator-next"))

    # Check that clicking the "..." paginator link
    # does not change the rendered page
    assert view
           |> element("a", "...")
           |> render_click()
           |> Floki.parse_document()
           |> elem(1)
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.any?()

    # Check that changing the sort order resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10")

    document =
      view |> render() |> Floki.parse_document() |> elem(1)

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.empty?()

    document =
      view
      |> render_click("sort", %{"sort-by" => "date_asc"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.empty?()

    # Check that changing search query resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10")

    document =
      view
      |> element("#search-form")
      |> render_submit(%{"q" => "Document*"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.empty?()

    # Check that updating the date query resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10")

    document =
      view
      |> element("#search-form")
      |> render_submit(%{"date-from" => "1900", "date-to" => "2025"})
      |> Floki.parse_document()
      |> elem(1)

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.empty?()
  end

  test "item counter element", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search?page=1&per_page=7")
    assert view |> has_element?("#item-counter", "1 - 7 of 100")

    {:ok, view, _html} = live(conn, ~p"/search?page=5&per_page=7")
    assert view |> has_element?("#item-counter", "29 - 35 of 100")

    {:ok, view, _html} = live(conn, ~p"/search?page=15&per_page=7")
    assert view |> has_element?("#item-counter", "99 - 100 of 100")

    {:ok, view, _html} = live(conn, ~p"/search?q=notavalidsearch")
    assert view |> has_element?("#item-counter", "No items found")
  end
end
