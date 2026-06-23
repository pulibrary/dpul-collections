defmodule DpulCollectionsWeb.Features.HomeTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case, headless: false
  alias DpulCollections.Solr

  test "home page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> assert_has(".phx-connected")
    |> assert_has("a", text: "Explore")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  test "site title is not shown in header, page has it in h1", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has(".phx-connected")
    |> refute_has("header", text: "Digital Collections")
    |> assert_has("h1", text: "Digital Collections")
    |> click_link("pamphlets")
    |> assert_has("header", text: "Digital Collections")
  end

  # Configure mobile display port - see
  # https://playwright.dev/docs/api/class-browser#browser-new-context and https://phoenix-test-playwright.hexdocs.pm/0.14.0/PhoenixTest.Playwright.Config.html
  @tag browser_context_opts: [
         viewport: %{width: 375, height: 667}
       ]
  test "home page elements have no scroll on mobile", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(5), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> PhoenixTest.Playwright.evaluate(
      "document.documentElement.scrollWidth == document.documentElement.clientWidth",
      &assert(&1 == true)
    )
  end

  test "home page has recently added items", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(5), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> assert_has(".phx-connected")
    |> assert_has("#recent-items h2", text: "Recently Added Items")
    |> assert_has("#browse-item-5", text: "Date")
    |> assert_has("#browse-item-5", text: "2020")
    # Test that origin does not appear if geographic_origin is empty
    |> refute_has("#browse-item-5", text: "Origin")
  end

  test "home page has collections", %{conn: conn} do
    FiggyTestSupport.index_record_id_directly("2961c153-54ab-4c6a-b5cd-aa992f4c349b")
    FiggyTestSupport.index_record_id_directly("02c8124b-5133-487e-9646-7896bba289a2")
    Solr.soft_commit(active_collection())

    collection_id = "#browse-collection-2961c153-54ab-4c6a-b5cd-aa992f4c349b"

    conn
    |> visit("/")
    |> assert_has(".phx-connected")
    |> assert_has("#collections h2", text: "Collections")
    |> assert_has(collection_id, text: "Woman Life Freedom Movement: Iran 2022")
    |> assert_has("#{collection_id} .item-count", text: "Items")
    |> assert_has("#{collection_id} .item-count", text: "1")
    |> assert_has("#{collection_id} .languages-count", text: "Languages")
    |> assert_has("#{collection_id} .languages-count", text: "1")
    |> assert_has("#{collection_id} .locations-count", text: "Locations")
    |> assert_has("#{collection_id} .locations-count", text: "1")
  end
end
