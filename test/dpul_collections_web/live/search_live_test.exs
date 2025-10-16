defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.soft_commit(active_collection())
    :ok
  end

  describe "GET /search" do
    test "with no parameters returns all items", %{conn: conn} do
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

    test "with a blank q parameter returns all items", %{conn: conn} do
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

    test "with an ephemera project indexed displays it", %{conn: conn} do
      conn = get(conn, ~p"/search?q=Amazing+Project")

      {:ok, document} =
        html_response(conn, 200) |> Floki.parse_document()

      assert document
             |> Floki.find(~s{a[href="/i/document1/item/1"]})
             |> Enum.any?()
    end

    test "with a query that has no results displays a no items found page", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search?q=therewontbeanyresults")

      assert view
             |> has_element?(
               "#item-counter",
               "No items found"
             )

      # There aren't any filters
      refute view
             |> has_element?("#filter-form")

      # There's no sort dropdown
      refute view
             |> has_element?("#sort-form")
    end
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

  test "can activate filters", %{conn: conn} do
    {:ok, view, html} = live(conn, "/search?")

    assert html =~ "Filter your 100 results"
    refute html =~ "Applied Filters"

    # Clicking the button shows the filters.
    view
    |> element("button", "Genre")
    |> render_click()

    assert view |> has_element?("div.expanded[role='tabpanel']")

    # Clicking the button again hides the filters.
    view
    |> element("button", "Genre")
    |> render_click() =~ "Folders"

    refute view |> has_element?("div.expanded[role='tabpanel']")

    # Let's toggle it back on so we can click the Folders genre.
    view
    |> element("button", "Genre")
    |> render_click()

    assert view
           |> element("#filter-form")
           |> render_change(%{_target: ["filter", "genre"], filter: %{genre: ["Folders"]}})
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "of 50"

    assert view
           |> has_element?(".filter", "Folders")

    # I can pick a second genre to make an OR
    assert view
           |> element("#filter-form")
           |> render_change(%{
             _target: ["filter", "genre"],
             filter: %{genre: ["Folders", "Pamphlets"]}
           })
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "of 100"

    # Make sure there's two independent pills.
    assert element(view, ".filter", "Pamphlets") != element(view, ".filter", "Folders")

    # Removing one pill doesn't remove the other
    assert view
           |> element(".filter", "Pamphlets")
           |> render_click()
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "of 50"

    # I can remove it from the checkbox
    assert view
           |> element("#filter-form")
           |> render_change(%{"_target" => ["filter", "genre"], "filter" => %{"genre" => nil}})
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "of 100"

    refute view |> has_element?(".expanded input[name='filter[year][from]']")

    # I can add a year filter
    view
    |> element("button", "Year")
    |> render_click()

    assert view |> has_element?(".expanded input[name='filter[year][from]']")

    # Typing into a year filter doesn't do anything.
    view
    |> element("#filter-form")
    |> render_change(%{
      "_target" => ["filter", "year", "from"],
      "filter" => %{"year" => %{"from" => "201"}}
    })

    refute view
           |> has_element?(".filter", "Year")
  end

  test "renders active filters with states", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/search?")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # Only filters that are in use / active should display
    assert document |> Floki.find(".year.filter") |> Enum.empty?()
    assert document |> Floki.find(".genre.filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[year][to]=2025")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find(".year.filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year Up to 2025"

    assert document |> Floki.find(".genre.filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[year][from]=2020&filter[year][to]=")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find(".year.filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year 2020 to Now"

    assert document |> Floki.find(".genre.filter") |> Enum.empty?()

    {:ok, _view, html} = live(conn, "/search?filter[genre][]=posters")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document |> Floki.find(".year.filter") |> Enum.empty?()

    assert document
           |> Floki.find(".genre.filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Genre posters"

    {:ok, _view, html} = live(conn, "/search?filter[genre][]=posters&filter[year][to]=2025")

    {:ok, document} =
      html
      |> Floki.parse_document()

    assert document
           |> Floki.find(".year.filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Year Up to 2025"

    assert document
           |> Floki.find(".genre.filter")
           |> Floki.text()
           |> TestUtils.clean_string() == "Genre posters"
  end

  test "adding and removing filters sets page back to 1", %{conn: conn} do
    # Add more documents so that we can still paginate after filtering
    Solr.add(SolrTestSupport.mock_solr_documents(210), active_collection())
    Solr.soft_commit(active_collection())

    {:ok, view, html} = live(conn, "/search?")

    assert html =~ "1 - 50 of 210"

    # go to the next page
    {:ok, view, html} =
      view
      |> element("#paginator-next")
      |> render_click()
      |> follow_redirect(conn)

    assert html
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "51 - 100 of 210"

    # selecting a filter goes back to page 1
    view
    |> element("button", "Genre")
    |> render_click()

    assert view
           |> element("#filter-form")
           |> render_change(%{_target: ["filter", "genre"], filter: %{genre: ["Folders"]}})
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "1 - 50 of 105"

    # go to the next page
    {:ok, view, html} =
      view
      |> element("#paginator-next")
      |> render_click()
      |> follow_redirect(conn)

    assert html
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "51 - 100 of 105"

    # Removing a pill goes back to page 1
    view
    |> element("button", "Genre")
    |> render_click()

    assert view
           |> element(".filter", "Folders")
           |> render_click()
           |> Floki.parse_document!()
           |> Floki.find("#item-counter")
           |> Floki.text() =~ "1 - 50 of 210"
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
          title_txtm: "Document-nildate",
          file_count_i: 1
        },
        %{
          id: "emptydate",
          title_txtm: "Document-emptydate",
          years_is: [],
          file_count_i: 1
        }
      ],
      active_collection()
    )

    Solr.soft_commit()

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
      |> element("#filter-form")
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
    {:ok, _view, html} = live(conn, "/search?filter[stuff][]=1")

    {:ok, document} = Floki.parse_document(html)

    assert document
           |> Floki.find(~s{.filter})
           |> Enum.empty?()
  end

  test "items can be filtered by similarity", %{conn: conn} do
    {:ok, view, html} = live(conn, "/search?filter[similar]=2")

    {:ok, document} =
      html
      |> Floki.parse_document()

    # There's a similarity filter.
    assert document
           |> Floki.find(".filter.similar")
           |> Floki.text()
           |> TestUtils.clean_string() == "Similar To Document-2"

    # It finds the other folders - those are similar.
    assert document
           |> Floki.find(~s{a[href="/i/document4/item/4"]})
           |> Enum.any?()

    assert document
           |> Floki.find(~s{a[href="/i/document6/item/6"]})
           |> Enum.any?()

    # The filter can be removed.
    view
    |> element(".filter", "Similar")
    |> render_click()

    refute has_element?(view, ".filter.similar")
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
      |> element("#filter-form")
      |> render_submit(%{"filter" => %{"year" => %{"from" => nil, "to" => nil}}})
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

  describe "results" do
    test "can search for subjects", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?#{%{q: "arts"}}")

      assert html =~ "Document-1"
    end

    test "can search for stemmed metadata", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?#{%{q: "art"}}")

      assert html =~ "Document-1"
    end

    test "display large and small thumbnails", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/search?")

      {:ok, document} =
        html
        |> Floki.parse_document()

      # There should be a maximum of 5 thumbnails on the search results page
      assert document |> Floki.find("#item-1 img") |> Enum.count() == 7

      # Odd numbered documents in test data do not have a thumbnail id
      # so the order of thumbnails should be the same as the image member order
      assert document
             |> Floki.attribute("#item-1 .search-thumbnail img", "src") == [
               "https://example.com/iiif/2/image1/full/!350,350/0/default.jpg"
             ]

      assert document
             |> Floki.attribute("#item-1 .small-thumbnails > :first-child > img", "src") == [
               "https://example.com/iiif/2/image2/square/350,350/0/default.jpg"
             ]

      # Even numbered documents in test data have a thumbnail id so the order
      # of thumbnails should be different from the image member order
      assert document
             |> Floki.attribute("#item-2 .search-thumbnail img", "src") == [
               "https://example.com/iiif/2/image2/full/!350,350/0/default.jpg"
             ]

      assert document
             |> Floki.attribute("#item-2 .small-thumbnails > :first-child > img", "src") == [
               "https://example.com/iiif/2/image1/square/350,350/0/default.jpg"
             ]
    end

    test "displays ephemera projects", %{conn: conn} do
      sae_ids = [
        "f99af4de-fed4-4baa-82b1-6e857b230306",
        "e379b822-27cc-4d0e-bca7-6096ac38f1e6"
      ]

      sae_ids
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit()
      sae_id = "f99af4de-fed4-4baa-82b1-6e857b230306"

      {:ok, view, _html} = live(conn, ~p"/search?#{%{q: "South Asian Ephemera"}}")
      # Search result works.
      item_card = view |> element("#item-#{sae_id}")
      assert item_card |> has_element?
      # Link to collection page.
      assert view |> element("#item-#{sae_id} a[href='/collections/sae']") |> has_element?
      card_content = item_card |> render()
      # Tagline renders.
      assert card_content =~ "Discover voices of change"
      # Digital Collection genre renders
      assert card_content =~ "Digital Collection"
      # Mosaic images
      assert view |> element("#item-#{sae_id} .search-thumbnail img") |> has_element?
      # Stats
      assert card_content =~ "1"
      assert card_content =~ "Items"
    end

    test "link to record page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search?q=")

      assert view |> element(".card a[href='/i/document1/item/1']") |> has_element? == true
    end

    test "show some metadata", %{conn: conn} do
      Solr.add(
        [
          %{
            id: "iran",
            title_txtm: "Women's Movement Art",
            genre_txt_sort: "Ephemera",
            display_date_s: "2024",
            years_is: [2024],
            geographic_origin_txt_sort: "Iran"
          }
        ],
        active_collection()
      )

      Solr.soft_commit()

      {:ok, view, _html} = live(conn, "/search?q=movement")

      assert view
             |> has_element?(
               "#item-iran .metadata",
               "Ephemera"
             )

      assert view
             |> has_element?(
               "#item-iran .metadata",
               "2024"
             )

      assert view
             |> has_element?(
               "#item-iran .metadata",
               "Iran"
             )
    end
  end
end
