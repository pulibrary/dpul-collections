defmodule DpulCollectionsWeb.Features.SearchBarTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "submitting a search via the search bar component on the search page", %{conn: conn} do
    conn
    |> visit("/search")
    |> fill_in("Search", with: "Document-3")
    |> within(".search-bar", fn session ->
      session
      |> click_button("Search")
    end)
    |> assert_has("#item-counter", text: "1 - 1 of 1")
  end

  test "submitting a search on the home page", %{conn: conn} do
    conn
    |> visit("/")
    |> fill_in("Search", with: "Document-3")
    |> click_button("Search")
    |> assert_has("#item-counter", text: "1 - 1 of 1")
  end
end
