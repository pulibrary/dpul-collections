defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature

  import Wallaby.Query

  feature "locale persists between pages", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("h3", text: "Explore Our Digital Collections"))
    |> click(button("Language"))
    |> click(link("Español"))
    |> assert_has(css("h3", text: "Explora nuestras colecciones"))
    |> click(button("Buscar"))
    |> assert_has(css("div#filters", text: "Relevancia"))
  end
end
