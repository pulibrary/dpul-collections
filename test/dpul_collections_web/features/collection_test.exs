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
      "8ac0a23b-8c51-4e1c-8bc0-ae307264b895",
      "f99af4de-fed4-4baa-82b1-6e857b230306",
      "e8abfa75-253f-428a-b3df-0e83ff2b20f9",
      "e379b822-27cc-4d0e-bca7-6096ac38f1e6",
      "1e5ae074-3a6e-494e-9889-6cd01f7f0621",
      "036b86bf-28b0-4157-8912-6d3d9eeaa5a8",
      "d82efa97-c69b-424c-83c2-c461baae8307",
      "39a1a1a0-7ba6-4de9-8a44-f081811c2b34"
    ]

    # Add another ID so we know it doesn't include counts from other collections.
    other_ids = ["3da68e1c-06af-4d17-8603-fc73152e1ef7", "118983a5-dd6b-4d7a-bb8c-93fb08248cac"]

    (sae_ids ++ other_ids)
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
      |> assert_has("div", text: "14 items")
      |> assert_has("div", text: "3 Languages")
      |> assert_has("div", text: "4 Locations")
      # Browse button
      |> assert_has("a[href='/search?filter[project][]=South+Asian+Ephemera']",
        text: "Browse Collection"
      )
      # Mosaic
      |> assert_has("#collection-mosaic .card-darkdrop", count: 4)
      # Featured Items
      |> assert_has("#featured-items .browse-item", count: 4)
      # Learn More collapse/expand
      |> assert_has("div", text: "The South Asian Ephemera Collection complements Princeton's")
      |> assert_has("li", text: "Politics and government")
      # Subject tag expansion
      |> refute_has("li", text: "Socioeconomic conditions and development")
      |> within("#categories-container", fn conn ->
        conn
        |> click_button("more")
      end)
      |> assert_has("li", text: "Socioeconomic conditions and development")
      |> click_button("Show less")
      |> refute_has("li", text: "Socioeconomic conditions and development")
      # Genres
      |> assert_has("li", text: "Posters")
      # No more link if it's displaying them all
      |> refute_has("li", text: "+0 more")
      # Recently updated more link
      |> assert_has(
        "a[href='/search?filter[project][]=South+Asian+Ephemera&sort_by=recently_added']"
      )
      # Recently Updated cards
      |> assert_has(
        "#recent-items .card",
        count: 4
      )
      # Contributors
      |> assert_has(
        "#contributors .contributor-card",
        count: 1
      )
    end

    test "it links to filtered search result sets", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> click_link("Politics and government")
      |> assert_has("h1", text: "Search Results")
      |> assert_has("a.category", text: "Politics and government")
      |> assert_has("a.project", text: "South Asian Ephemera")
    end
    
    test "a collection without contributors still displays copyright policy", %{conn: conn} do
      conn
      |> visit("/collections/soviet_posters")
      # Title
      |> assert_has("h1", text: "Russian")
      # Contributors
      |> assert_has(
        "#contributors .contributor-card",
        count: 0
      )
      # Copyright
      |> assert_has(
        "#policies",
        count: 1
      )
    end

    test "collection page is accessible", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> unwrap(&TestUtils.assert_a11y/1)
    end
  end
end
