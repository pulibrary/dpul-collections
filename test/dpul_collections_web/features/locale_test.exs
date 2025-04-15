defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case, async: true
  use PhoenixTest.Playwright.Case, async: true
  alias PhoenixTest.Playwright

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
end
