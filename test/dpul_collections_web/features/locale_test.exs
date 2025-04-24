defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright
  import SolrTestSupport
  alias DpulCollections.Solr

  test "locale persists between pages", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("a", text: "Browse all items")
    |> click_button("Language")
    |> Playwright.click("//div[text()='Español']")
    |> assert_has("a", text: "Explorar todos los materiales")
    |> fill_in("Buscar", with: " ")
    |> click_button("Buscar")
    |> assert_has("label", text: "filtrar por fecha:")
  end

  # Testing because these translations happen in a separate library and are not handled by Gettext
  test "renders time-ago language with translation", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("#browse-item-9", text: "Added 3 months ago")
    |> click_button("Language")
    |> Playwright.click("//div[text()='Español']")
    |> assert_has("#browse-item-9", text: "Añadido hace 3 meses")

    Solr.delete_all(active_collection())
  end

  test "renders facet with states", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

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

    Solr.delete_all(active_collection())
  end
end
