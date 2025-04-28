defmodule DpulCollectionsWeb.Features.SearchBarTest do
  use ExUnit.Case, async: true
  use PhoenixTest.Playwright.Case, async: true
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

  test "renders facet with states", %{conn: conn} do
    conn
    |> visit("/search")
    |> refute_has("#year-facet", text: "YEAR")
    |> refute_has("#genre-facet", text: "GENRE")
    |> visit("/search?date_to=2025")
    |> assert_has("#year-facet", text: "YEAR UP TO 2025")
    |> visit("/search?date_from=2020")
    |> assert_has("#year-facet", text: "YEAR 2020 TO NOW")
    |> visit("/search?genre=posters")
    |> assert_has("#genre-facet", text: "Genre Posters")
  end

  test "displays digitized date only when sorting by recently added", %{conn: conn} do
    conn
    |> visit("/search")
    |> fill_in("Search", with: "Document-3")
    |> within(".search-bar", fn session ->
      session
      |> click_button("Search")
    end)
    |> refute_has(".digitized_at", text: "Added")
    |> visit("/search?sort_by=recently_added")
    |> assert_has(".digitized_at", text: "Added")
  end
end
