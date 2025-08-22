defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "GET /search", %{conn: conn} do
    conn = get(conn, ~p"/search")

    {:ok, document} =
      html_response(conn, 200)
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()
  end

  test "GET /search with blank q parameter", %{conn: conn} do
    conn = get(conn, ~p"/search?q=")

    {:ok, document} =
      html_response(conn, 200) |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()
  end

  test "GET /search with a query that has no results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search?q=therewontbeanyresults")

    assert view
           |> has_element?(
             "#item-counter",
             "No items found"
           )
  end

  test "GET /search renders thumbnails for each resource", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/search?")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # There should be a maximum of 5 thumbnails on the search results page
    assert document |> Floki.find("#item-1 > a > div > img") |> Enum.count() == 5

    # Odd numbered documents in test data do not have a thumbnail id
    # so the order of thumbnails should be the same as the image member order
    assert document
           |> Floki.attribute("#item-1 > a > div > :first-child", "src") == [
             "https://example.com/iiif/2/image1/square/350,350/0/default.jpg"
           ]

    assert document
           |> Floki.attribute("#item-1 > a > div > :nth-child(2)", "src") == [
             "https://example.com/iiif/2/image2/square/350,350/0/default.jpg"
           ]

    # Even numbered documents in test data have a thumbnail id so the order
    # of thumbnails should be different from the image member order
    assert document
           |> Floki.attribute("#item-2 > a > div > :first-child", "src") == [
             "https://example.com/iiif/2/image2/square/350,350/0/default.jpg"
           ]

    assert document
           |> Floki.attribute("#item-2 > a > div > :nth-child(2)", "src") == [
             "https://example.com/iiif/2/image1/square/350,350/0/default.jpg"
           ]
  end

  test "searching filters results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search?")

    {:ok, document} =
      view
      |> element("#search-form")
      |> render_submit(%{"q" => "Document-2"})
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()
  end

  test "items can be sorted by date, ascending and descending", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    {:ok, document} =
      view
      |> render_click("sort", %{"sort-by" => "date_asc"})
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()

    {:ok, document} =
      view
      |> render_click("sort", %{"sort-by" => "date_desc"})
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.empty?()
  end

  test "items can be sorted by recently updated", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    {:ok, document} =
      view
      |> render_click("sort", %{"sort-by" => "recently_updated"})
      |> Floki.parse_document()

    # Note: 100 items are generated in solr_test_support.ex from oldest to newest.
    # Because of this, the test expects the 100th item to be on the front page when 
    # sorted by recently_updated. 
    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()

    assert document
           |> Floki.find(~s{a[href="/i/document100/item/100"]})
           |> Enum.any?()
  end

  test "items should display time ago when sorted by recently_updated", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/search?sort_by=recently_updated")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # Items should display digitized at information
    assert document |> Floki.find(".updated-at") |> Enum.any?()
  end

  test "items should not display time ago information when not sorted by recently_updated", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/search?")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # Items should not display digitized at information
    assert document |> Floki.find(".digitized_at") |> Enum.empty?()
  end

  test "renders active filters with states", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/search?")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # Only filters that are in use / active should display
    assert document |> Floki.find("#year-filter") |> Enum.empty?()
    assert document |> Floki.find("#genre-filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[year][to]=2025")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find("#year-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year Up to 2025"

    assert document |> Floki.find("#genre-filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[year][from]=2020&filter[year][to]=")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find("#year-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year 2020 to Now"

    assert document |> Floki.find("#genre-filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[genre]=posters")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document |> Floki.find("#year-filter") |> Enum.empty?()

    assert document
           |> Floki.find("#genre-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Genre posters"

    {:ok, _view, html} = live(conn, "/search?filter[genre]=posters&filter[year][to]=2025")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find("#year-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year Up to 2025"

    assert document
           |> Floki.find("#genre-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Genre posters"
  end

  test "changing query parameter resets sort_by to default", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    view |> render_click("sort", %{"sort-by" => "date_asc"})
    assert_patched(view, "/search?sort_by=date_asc")

    view
    |> element("#search-form")
    |> render_submit(%{"q" => "Document"})

    assert_redirected(view, "/search?q=Document")
  end

  test "when sorting by date, a nil date always sorts last", %{conn: conn} do
    Solr.add(
      [
        %{
          id: "nildate",
          title_txtm: "Document-nildate"
        },
        %{
          id: "emptydate",
          title_txtm: "Document-emptydate",
          years_is: []
        }
      ],
      active_collection()
    )

    Solr.commit()

    {:ok, view, _html} = live(conn, "/search?sort_by=date_desc&page=3")

    assert view
           |> has_element?(~s{a[href="/i/documentnildate/item/nildate"]})

    assert view
           |> has_element?(~s{a[href="/i/documentemptydate/item/emptydate"]})

    {:ok, view, _document} = live(conn, "/search?sort_by=date_asc&page=3")

    assert view
           |> has_element?(~s{a[href="/i/documentnildate/item/nildate"]})

    assert view
           |> has_element?(~s{a[href="/i/documentemptydate/item/emptydate"]})
  end

  test "items can be filtered by date range", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    {:ok, document} =
      view
      |> element("#date-filter")
      |> render_submit(%{"filter" => %{"year" => %{"from" => "1925", "to" => "1926"}}})
      |> Floki.parse_document()

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

  test "unknown filters are ignored", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/search?filter[stuff]=1")

    {:ok, document} = Floki.parse_document(html)

    assert document
           |> Floki.find(~s{.filter})
           |> Enum.empty?()
  end

  test "items can be filtered by genre", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    {:ok, document} =
      view
      |> element("#item-2 a", "Folders")
      |> render_click()
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

    # Only folders
    assert document
           |> Floki.find(~s{a[href="/i/document2/item/2"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document4/item/4"]})
           |> Enum.any?()

    # Odd numbered ones are pamphlets.
    assert document
           |> Floki.find(~s{a[href="/i/document1/item/1"]})
           |> Enum.empty?()
  end

  test "items can be filtered by similarity", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/search?filter[similar]=2")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # There's a similarity filter.
    assert document
           |> Floki.find("#similar-filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Similar To Document-2"

    # It finds the other folders - those are similar.
    assert document
           |> Floki.find(~s{a[href="/i/document4/item/4"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document6/item/6"]})
           |> Enum.any?()
  end

  test "paginator works as expected", %{conn: conn} do
    # Check that the previous link is hidden on the first page
    {:ok, view, _html} = live(conn, ~p"/search?page=1")
    assert !(view |> has_element?("#paginator-previous"))
    assert view |> has_element?("#paginator-next")

    # Check that the previous and next links are displayed and work as expected
    {:ok, view, _html} = live(conn, ~p"/search?page=5&per_page=10")
    assert(view |> element(".paginator > span.active", ~r(5)) |> has_element?())

    {:ok, document} =
      view
      |> element("#paginator-previous")
      |> render_click()
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document40/item/40"]})
           |> Enum.any?()

    {:ok, view, _html} = live(conn, ~p"/search?page=4&per_page=10")

    {:ok, document} =
      view
      |> element("#paginator-next")
      |> render_click()
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

    assert document
           |> Floki.find(~s{a[href="/i/document50/item/50"]})
           |> Enum.any?()

    # Check that the next link is hidden on the last page
    {:ok, view, _html} = live(conn, ~p"/search?page=10&per_page=10")
    assert view |> has_element?("#paginator-previous")
    assert !(view |> has_element?("#paginator-next"))

    # Check that the ellipses appears
    assert view |> has_element?("span", "...")

    # Check that changing the sort order resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10&per_page=10")

    {:ok, document} =
      view |> render() |> Floki.parse_document()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.empty?()

    {:ok, document} =
      view
      |> render_click("sort", %{"sort-by" => "date_asc"})
      |> Floki.parse_document()

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.empty?()

    # Check that changing search query resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10&per_page=10")

    {:ok, document} =
      view
      |> element("#search-form")
      |> render_submit(%{"q" => "Document*"})
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

    assert document
           |> Floki.find("a[phx-value-page=2]")
           |> Enum.any?()

    assert document
           |> Floki.find("a[phx-value-page=9]")
           |> Enum.empty?()

    # Check that updating the date query resets the paginator
    {:ok, view, _html} = live(conn, ~p"/search?page=10&per_page=10")

    {:ok, document} =
      view
      |> element("#search-form")
      |> render_submit(%{"date-from" => "1900", "date-to" => "2025"})
      |> follow_redirect(conn)
      |> elem(2)
      |> Floki.parse_document()

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

  test "thumbnails link to record page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/search?q=")

    html = render(view)

    first_href =
      html
      |> Floki.parse_document!()
      |> Floki.find(".thumb-link")
      |> Enum.flat_map(&Floki.attribute(&1, "href"))
      |> Enum.at(0)

    assert first_href == "/i/document1/item/1"
  end

  test "page title", %{conn: conn} do
    {:ok, _, html} = live(conn, ~p"/search?q=")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "Search Results - Digital Collections"
  end
end
