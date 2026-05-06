defmodule DpulCollectionsWeb.Features.HomeTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
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
end
