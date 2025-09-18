defmodule DpulCollectionsWeb.Features.CollectionViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr
  import SolrTestSupport

  setup_all do
    sae_ids = [
      "01c4dc49-2ff9-49f6-98ce-fb6ca1c8ddcc",
      "d5610085-745c-46f2-b344-8bc5f6dd3dfb",
      "e906307b-2475-499f-80b7-194b6e0ae74e",
      "cb88573a-9091-411c-a366-f1747d76aca7",
      "8b6f89a7-984c-4a83-85a5-fdfba899e0c3",
      "1e86cab8-69c0-4e1f-8cf7-c11f274b657f",
      "666fcfd1-dda7-4603-82d1-1863dc97ffc3",
      "8ac0a23b-8c51-4e1c-8bc0-ae307264b895"
    ]

    sae_ids
    |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

    Solr.soft_commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
    :ok
  end

  describe "the collection page content" do
    test "it has content for the collection", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      # Title
      |> assert_has("h1", text: "South Asian Ephemera")
      # Subject summary
      |> assert_has("li", text: "Politics and government")
      # Count summary
      |> assert_has("div", text: "8 items")
      |> assert_has("div", text: "2 Languages")
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
