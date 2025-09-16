defmodule DpulCollectionsWeb.Features.CollectionViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case

  describe "the collection page content" do
    test "it has content for the collection", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      # Title
      |> assert_has("h1", text: "South Asian Ephemera")
      # Subject summary
      |> assert_has("li", text: "Politics and government")
      # Count summary
      |> assert_has("div", text: "3087 items")
      |> assert_has("div", text: "35 Languages")
      |> assert_has("div", text: "33 Locations")
      # Browse button
      |> assert_has("a[href='/search?filter[project]=South+Asian+Ephemera']",
        text: "Browse Collection"
      )
      # Learn More collapse/expand
      |> refute_has("p", text: "The South Asian Ephemera Collection complements Princeton's")
      |> click_button("Learn More")
      |> assert_has("p", text: "The South Asian Ephemera Collection complements Princeton's")
      |> click_button("Learn More")
      |> refute_has("p", text: "The South Asian Ephemera Collection complements Princeton's")
      # Subject tag expansion
      |> refute_has("li", text: "Tourism")
      |> click_button("+14 more")
      |> assert_has("li", text: "Tourism")
      |> click_button("Show less")
      |> refute_has("li", text: "Tourism")
      # Recently updated more link
      |> assert_has(
        "a[href='/search?filter[project]=South+Asian+Ephemera&sort_by=recently_updated']"
      )
    end

    test "collection page is accessible", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> unwrap(&TestUtils.assert_a11y/1)
    end
  end
end
