defmodule DpulCollectionsWeb.Features.HomeTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr

  test "home page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("a", text: "Explore")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  test "site title is not shown in header, page has it in h1", %{conn: conn} do
    conn
    |> visit("/")
    |> refute_has("header", text: "Digital Collections")
    |> assert_has("h1", text: "Digital Collections")
    |> click_link("pamphlets")
    |> assert_has("header", text: "Digital Collections")
  end
end
