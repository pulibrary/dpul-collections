defmodule DpulCollectionsWeb.Features.SearchBarTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    # index a sae project so there's a collection page
    FiggyTestSupport.index_record_id_directly("f99af4de-fed4-4baa-82b1-6e857b230306")
    Solr.soft_commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
    :ok
  end

  describe "on the search page" do
    test "submitting a search returns results", %{conn: conn} do
      conn
      |> visit("/search")
      |> assert_has(".phx-connected")
      |> assert_has("#search-button", text: "Search", exact: true)
      |> refute_has("#collection-search-button")
      |> fill_in("Search", with: "Document-3")
      |> click_button("Search")
      |> assert_has("#item-counter", text: "1 - 1 of 1")
    end
  end

  describe "on the home page" do
    test "submitting a search brings you to the results page", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has(".phx-connected")
      |> fill_in("Search", with: "Document-3")
      |> click_button("Search")
      |> assert_has("h1 span", text: "Document-3")
      |> assert_has("#item-counter", text: "1 - 1 of 1")
    end
  end

  describe "on a collection page" do
    test "submitting a search filters to that collection", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> assert_has(".phx-connected")
      |> assert_has("#search-button", text: "Search all", exact: true)
      |> assert_has("#collection-search-button")
      |> click_button("Search in this Collection")
      |> assert_has("section#filters", text: "Collection South Asian Ephemera")
    end
  end
end
