defmodule DpulCollectionsWeb.Features.SearchBarTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.soft_commit(active_collection())
    :ok
  end

  # Because the search button is only visible when the input is focused, we use
  # type instead of fill_in
  test "submitting a search via the search bar component on the search page", %{conn: conn} do
    conn
    |> visit("/search")
    |> Playwright.type("input#q", "Document-3")
    |> click_button("Search")
    |> assert_has("#item-counter", text: "1 - 1 of 1")
  end

  test "submitting a search on the home page", %{conn: conn} do
    conn
    |> visit("/")
    |> Playwright.type("input#q", "Document-3")
    |> click_button("Search")
    |> assert_has("#item-counter", text: "1 - 1 of 1")
  end

  test "search results page is accessible", %{conn: conn} do
    conn
    |> visit("/search?q=Document-3")
    |> unwrap(&TestUtils.assert_a11y/1)
  end
end
