defmodule DpulCollectionsWeb.Features.LocaleTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright
  alias DpulCollections.Solr

  # Because the search button is only visible when the input is focused, we use
  # type instead of fill_in
  test "locale persists between pages", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("a", text: "Explore")
    |> click_button("Language")
    |> click_link("Español")
    |> assert_has("a", text: "Explorar")
    |> Playwright.type("input#q", " ")
    |> click_button("Buscar")
    |> click("*[role=tab]", "Año")
    |> assert_has("label", text: "De")
  end

  test "the language dropdown is accessible", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("#language-nav button[aria-expanded='false']")
    |> refute_has("#language-menu a li")
    |> click_button("Language")
    |> assert_has("#language-nav button[aria-expanded='true']")
    |> assert_has("#language-menu a li")
    # Click away
    |> Playwright.click("input")
    |> refute_has("#language-menu a li")
    |> assert_has("#language-nav button[aria-expanded='false']")
    # Click twice
    |> click_button("Language")
    |> assert_has("#language-nav button[aria-expanded='true']")
    |> click_button("Language")
    |> assert_has("#language-nav button[aria-expanded='false']")
  end

  # Testing because these translations happen in a separate library and are not handled by Gettext
  test "renders time-ago language with translation", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("#browse-item-9", text: "Updated 3 months ago")
    |> click_button("Language")
    |> click_link("Español")
    |> assert_has("#browse-item-9", text: "Actualizado hace 3 meses")

    Solr.delete_all(active_collection())
  end
end
