defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case, async: true
  use PhoenixTest.Playwright.Case, async: true

  test "locale persists between pages", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h3", text: "Explore Our Digital Collections")
    |> click_button("Language")
    |> click_button("div", "Español")
    |> assert_has("h3", text: "Explora nuestras colecciones")
    |> click_button("Buscar")
    |> assert_has("label", text: "filtrar por fecha:")
  end
end
