defmodule DpulCollectionsWeb.Features.SearchBarTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright
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
      |> assert_has("#search-button")
      |> refute_has("#collection-search-button")
      # Because the search button is only visible when the input is focused, we use
      # type instead of fill_in
      |> Playwright.type("input#q", "Document-3")
      |> click_button("Search")
      |> assert_has("#item-counter", text: "1 - 1 of 1")
    end
  end

  describe "on the home page" do
    test "submitting a search brings you to the results page", %{conn: conn} do
      conn
      |> visit("/")
      |> Playwright.type("input#q", "Document-3")
      |> click_button("Search")
      |> assert_has("#item-counter", text: "1 - 1 of 1")
    end
  end

  describe "on a collection page" do
    test "submitting a search returns results", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> assert_has("#search-button")
      |> assert_has("#collection-search-button")
      # Because the search button is only visible when the input is focused, we use
      # type instead of fill_in
      |> Playwright.type("input#q", "Document-3")
      |> click_button("Search in this Collection")
      |> assert_has("#item-counter", text: "1 - 1 of 1")
    end
  end

  test "search results page is accessible", %{conn: conn} do
    conn
    |> visit("/search?q=Document-3")
    |> unwrap(&TestUtils.assert_a11y/1)
  end
end
