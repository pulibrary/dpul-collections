defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright
  import SolrTestSupport
  alias DpulCollections.Solr

  # Because the search button is only visible when the input is focused, we use
  # type instead of fill_in
  test "locale persists between pages", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("a", text: "Explore")
    |> click_button("Language")
    |> Playwright.click("//div[text()='Español']")
    |> assert_has("a", text: "Explorar")
    |> Playwright.type("input#q", " ")
    |> click_button("Buscar")
    |> assert_has("label", text: "filtrar por fecha:")
  end

  # Testing because these translations happen in a separate library and are not handled by Gettext
  test "renders time-ago language with translation", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("#browse-item-9", text: "Updated 3 months ago")
    |> click_button("Language")
    |> Playwright.click("//div[text()='Español']")
    |> assert_has("#browse-item-9", text: "Actualizado hace 3 meses")

    Solr.delete_all(active_collection())
  end
end
