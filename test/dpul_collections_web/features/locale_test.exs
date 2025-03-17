defmodule DpulCollectionsWeb.Features.LocaleTest do
  use ExUnit.Case, async: true
  use Wallaby.Feature

  import Wallaby.Query

  @tag ci: false
  feature "locale persists between pages", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("h3", text: "Explore Our Digital Collections"))
    |> click(button("Language"))
    |> click(Query.text("Español"))
    |> assert_has(css("h3", text: "Explora nuestras colecciones"))
    |> click(button("Buscar"))
    |> assert_has(css("div#filters", text: "Relevancia"))
  end

  @tag ci: false
  feature "existing params are preserved when locale is changed", %{session: session} do
    session =
      session
      |> visit("/")
      |> fill_in(text_field("q"), with: "foo")
      |> click(button("Search"))
      |> click(button("Language"))
      |> click(Query.text("Español"))
      |> assert_has(css("div#filters", text: "Relevancia"))

    field = find(session, text_field("q"))
    assert Element.value(field) == "foo"
  end
end
