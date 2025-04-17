defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case, async: true
  use PhoenixTest.Playwright.Case, async: true
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

  test "renders time-ago language with translation", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    conn
    |> visit("/")
    |> assert_has("#browse-item-10", text: "Added 3 months ago")
    |> click_button("Language")
    |> Playwright.click("//div[text()='Español']")
    |> assert_has("#browse-item-10", text: "Añadido hace 3 meses")

    Solr.delete_all(active_collection())
  end
end
