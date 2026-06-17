defmodule DpulCollectionsWeb.Features.SearchTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr
  alias PhoenixTest.Playwright

  test "filters are searchable", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    |> assert_has(".phx-connected")
    |> click_button("Filters")
    |> click_button("Format")
    |> assert_has("label", text: "Pamphlets")
    |> type("#filter-format-search", "older")
    |> assert_has("label", text: "Folder")
    |> refute_has("label", text: "Pamphlets")
    |> check("Folder", exact: false)
    |> assert_has(".filter.format")
    |> refute_has("label", text: "Pamphlets")
  end

  test "filters are retained when submitting form and tab is closed", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    |> assert_has(".phx-connected")
    |> click_button("Filters")
    |> click_button("Format")
    |> assert_has("label", text: "Pamphlets")
    |> check("Pamphlets", exact: false)
    |> click_button("#format-panel-button", "Format")
    |> click_button("View 5 results")
    |> refute_has("#filter-modal")
    |> click_button("Filters")
    |> click_button("View 5 results")
    |> assert_has(".filter.format")

    :timer.sleep(1000)
  end

  test "search results only display non-empty metadata", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(1), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    # Has Date label and value
    |> assert_has("#item-1 .date")
    |> assert_has("#item-1", text: "2024")
    # Has Publisher label and value
    |> assert_has("#item-1 .publisher")
    |> assert_has("#item-1", text: "PublisherInc")
    # Does not display orgin if item does not have geographic_orgin
    |> refute_has("#item-1 .origin")
  end

  describe "the 'f' filter hotkey" do
    test "toggles the filter modal open and closed", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      conn
      |> visit("/search?q=")
      |> assert_has(".phx-connected")
      |> refute_has("#filter-modal")
      |> Playwright.press("body", "f")
      |> assert_has("#filter-modal h2", text: "Filter Results")
      |> Playwright.press("body", "f")
      |> refute_has("#filter-modal")
    end

    test "is ignored when typing in the search input", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      conn
      |> visit("/search?q=")
      |> assert_has(".phx-connected")
      |> Playwright.press("#q", "f")
      |> refute_has("#filter-modal")
    end

    test "still toggles after a filter checkbox has been clicked", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      # Open the modal, then press 'f'
      conn
      |> visit("/search?q=")
      |> assert_has(".phx-connected")
      |> click_button("Filters")
      |> click_button("Format")
      |> check("Pamphlets", exact: false)
      |> Playwright.press("body", "f")
      |> refute_has("#filter-modal")
    end
  end

  test "search page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    |> assert_has(".phx-connected")
    |> unwrap(&TestUtils.assert_a11y/1)
    |> click_button("Filters")
    |> click_button("Format")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  test "image counts are shown when total files outnumber visible images", %{conn: conn} do
    Solr.add(
      [
        %{
          id: 1,
          title_txtm: ["Document-1"],
          display_date_s: "2025",
          years_is: [2025],
          file_count_i: 8,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2",
            "https://example.com/iiif/2/image3",
            "https://example.com/iiif/2/image4",
            "https://example.com/iiif/2/image5",
            "https://example.com/iiif/2/image6",
            "https://example.com/iiif/2/image7",
            "https://example.com/iiif/2/image8"
          ],
          image_canvas_ids_ss: [
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1",
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
          ],
          format_txt_sort: "Ephemera",
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image2"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    |> assert_has(".phx-connected")
    # when filecount exceeds visible images show image total
    |> assert_has("#item-1", text: "Document-1")
    # when visible images equals filecount don't show image total
    |> assert_has("#filecount-1", text: "8 Files")
  end

  describe "filter pill" do
    test "clicking the dismiss section removes the filter; clicking the body does not",
         %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      conn
      |> visit("/search?filter[format][]=Pamphlets")
      |> assert_has(".phx-connected")
      |> assert_has(".filter.format", text: "Pamphlets")
      # Click the body
      |> Playwright.click("#search-filters .filter.format .filter-body")
      |> assert_has(".filter.format", text: "Pamphlets")
      # Click the dismiss section
      |> Playwright.click("#search-filters .filter.format .filter-dismiss")
      |> refute_has(".filter.format")
    end

    test "clicking a collection filter pill body navigates to the collection page",
         %{conn: conn} do
      items =
        SolrTestSupport.mock_solr_documents(2)
        |> Enum.map(&Map.put(&1, :collection_titles_ss, ["Amazing Project"]))

      Solr.add(
        [
          %{
            id: "d7c889ba-9992-494e-8fe4-2c4a9b3c3d7d",
            title_txtm: ["Latin American Ephemera"],
            resource_type_s: "collection",
            authoritative_slug_s: "lae"
          }
          | items
        ],
        active_collection()
      )

      Solr.soft_commit(active_collection())

      conn
      |> visit("/search?filter[collection][]=Latin+American+Ephemera")
      |> assert_has(".phx-connected")
      |> Playwright.click("#search-filters .collection.filter .filter-body")
      |> assert_path("/collections/lae")
    end

    test "clicking a collection filter pill when the collection doesn't exist flashes an error",
         %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(2), active_collection())
      Solr.soft_commit(active_collection())

      conn
      |> visit("/search?filter[collection][]=Unindexed+Collection")
      |> assert_has(".phx-connected")
      |> Playwright.click("#search-filters .collection.filter .filter-body")
      |> assert_has("#flash-error", text: "Collection not found")
    end
  end

  test "filters are retained when adding a keyword", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?filter[format][]=Pamphlets")
    |> assert_has(".phx-connected")
    |> fill_in("Search", with: "Document-3")
    |> click_button("Search")
    |> assert_path("/search",
      query_params: %{q: "Document-3", filter: %{format: ["Pamphlets"]}, sort_by: "relevance"}
    )
    |> assert_has("h1 span", text: "Document-3")
    |> assert_has(".filter.format")
  end

  test "sort_by is retained when adding a keyword", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?sort_by=date_asc")
    |> assert_has(".phx-connected")
    |> fill_in("Search", with: "Document-3")
    |> click_button("Search")
    |> assert_path("/search", query_params: %{q: "Document-3", sort_by: "date_asc"})
  end

  test "both filters and sort_by are retained when adding a keyword", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?filter[format][]=Pamphlets&sort_by=date_asc")
    |> assert_has(".phx-connected")
    |> fill_in("Search", with: "Document-3")
    |> click_button("Search")
    |> assert_path("/search",
      query_params: %{q: "Document-3", sort_by: "date_asc", filter: %{format: ["Pamphlets"]}}
    )
  end

  test "successfully submit a new search when no filtering has been done", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=Document-1")
    |> assert_has(".phx-connected")
    |> fill_in("Search", with: "Document-3")
    |> click_button("Search")
    |> assert_path("/search", query_params: %{q: "Document-3", sort_by: "relevance"})
    |> assert_has("h1 span", text: "Document-3")
  end

  test "long search queries don't error", %{conn: conn} do
    Solr.add(
      [
        %{
          id: 1,
          title_txtm: [
            "al-Maḥāsin al-mujtamaʻah fī faḍl faḍāyil al-khulafāʼ al-arbaʻah / lil-Shaykh ʻAlī al-Ṣaffūrī."
          ],
          display_date_s: "1704",
          years_is: [1704],
          file_count_i: 1,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1"
          ],
          image_canvas_ids_ss: [
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1"
          ],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())

    conn
    |> visit(
      "/search?q=al-Maḥāsin+al-mujtamaʻah+fī+faḍl+faḍāyil+al-khulafāʼ+al-arbaʻah+%2F+lil-Shaykh+ʻAlī+al-Ṣaffūrī"
    )
    |> assert_has(".phx-connected")
    |> assert_has("#item-1",
      text:
        "al-Maḥāsin al-mujtamaʻah fī faḍl faḍāyil al-khulafāʼ al-arbaʻah / lil-Shaykh ʻAlī al-Ṣaffūrī."
    )
  end
end
