defmodule DpulCollectionsWeb.Features.CollectionViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr
  alias PhoenixTest.Playwright
  import SolrTestSupport
  import Mock

  setup_all do
    on_exit(fn -> Solr.delete_all(active_collection()) end)
    :ok
  end

  describe "the collection page content for an EphemeraProject" do
    setup do
      sae_ids = [
        "01c4dc49-2ff9-49f6-98ce-fb6ca1c8ddcc",
        "d5610085-745c-46f2-b344-8bc5f6dd3dfb",
        "e906307b-2475-499f-80b7-194b6e0ae74e",
        "cb88573a-9091-411c-a366-f1747d76aca7",
        "8b6f89a7-984c-4a83-85a5-fdfba899e0c3",
        "1e86cab8-69c0-4e1f-8cf7-c11f274b657f",
        "666fcfd1-dda7-4603-82d1-1863dc97ffc3",
        "8ac0a23b-8c51-4e1c-8bc0-ae307264b895",
        "5f78bc1d-940d-4628-9421-98818e3dea35",
        # the project
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

    test "it has content for the collection", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> assert_has(".phx-connected")
      # Title
      |> assert_has("h1", text: "South Asian Ephemera")
      # Subject summary
      |> assert_has("li", text: "Politics and government")
      # Count summary
      |> assert_has("div", text: "15 items")
      |> assert_has("div", text: "4 Languages")
      |> assert_has("div", text: "4 Locations")
      # Browse button
      |> assert_has("a[href='/search?filter[collection][]=South+Asian+Ephemera']",
        text: "Browse Collection"
      )
      # Banner image area
      |> assert_has("#collection-banner", count: 1)
      # Banner item link
      |> assert_has(
        "#collection-banner a[href='/i/70th-year-womens-indian-association/item/5f78bc1d-940d-4628-9421-98818e3dea35']"
      )
      # Banner image
      |> assert_has(
        "#collection-banner img[src='https://iiif-cloud.princeton.edu/iiif/2/a1%2F2d%2Fdc%2Fa12ddc0476d147c0a3571a109c9e4e32%2Fintermediate_file/354,1295,1551,1034/750,/0/default.jpg']"
      )
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
      # Formats
      |> assert_has("li", text: "Posters")
      # No more link if it's displaying them all
      |> refute_has("li", text: "+0 more")
      # Languages
      |> assert_has("li", text: "Hindi")
      # Recently updated more link
      |> assert_has(
        "a[href='/search?filter[collection][]=South+Asian+Ephemera&sort_by=recently_added']"
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
      |> assert_has(".phx-connected")
      |> click_link("Politics and government")
      |> assert_has("h1", text: "Search Results")
      |> assert_has(".filter.category", text: "Politics and government")
      |> assert_has(".filter.collection", text: "South Asian Ephemera")
    end

    test "a collection without contributors still displays copyright policy", %{conn: conn} do
      conn
      |> visit("/collections/soviet_posters")
      |> assert_has(".phx-connected")
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
      |> assert_has(".phx-connected")
      |> unwrap(&TestUtils.assert_a11y/1)
    end

    test "it has recently added items", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> assert_has(".phx-connected")
      |> assert_has("#recent-items h2", text: "Recently Added Items")
      |> assert_has("#recent-items .card .date")
      |> assert_has("#recent-items .card .geographic_origin")
    end

    @tag browser_context_opts: [
           viewport: %{width: 375, height: 667}
         ]
    test "there is no horizontal scroll on mobile", %{conn: conn} do
      conn
      |> visit("/collections/sae")
      |> PhoenixTest.Playwright.evaluate(
        "document.documentElement.scrollWidth == document.documentElement.clientWidth",
        &assert(&1 == true)
      )
    end
  end

  describe "the collection page content for a Figgy Collection" do
    setup do
      [
        # Manuscripts of the islamic world collection
        "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
        # featured item
        "159ba3f9-feab-49dd-bc71-ca08995006d9"
      ]
      |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

      Solr.soft_commit(active_collection())

      on_exit(fn -> Solr.delete_all(active_collection()) end)
      :ok
    end

    test "it has content for the collection", %{conn: conn} do
      conn
      |> visit("/collections/islamicmss")
      |> assert_has(".phx-connected")
      # Title
      |> assert_has("h1", text: "Manuscripts of the Islamic World")
      # Subject summary
      |> refute_has("h2", text: "Subject Areas")
      # Format summary
      |> assert_has("h2", text: "Formats")
      # Count summary
      |> assert_has("div", text: "1 items")
      |> assert_has("div", text: "Languages")
      |> refute_has("div", text: "Locations")
      # Browse button
      |> assert_has(
        "a[href='/search?filter[collection][]=Manuscripts+of+the+Islamic+World']",
        text: "Browse Collection"
      )
      # Featured Items
      |> assert_has("#featured-items .browse-item", count: 1)
      # Recently Updated cards
      |> assert_has(
        "#recent-items .card",
        count: 1
      )
    end
  end

  describe "A collection with no banner image selected" do
    setup do
      with_mock DpulCollections.IndexingPipeline.Figgy.HydrationConsumer, [:passthrough],
        process?: fn _ -> true end do
        [
          # Middle East Manuscripts collection
          "3bab572e-6603-4abf-8305-16ce6fe3ac5c",
          # featured item
          "159ba3f9-feab-49dd-bc71-ca08995006d9"
        ]
        |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)
      end

      Solr.soft_commit(active_collection())
      on_exit(fn -> Solr.delete_all(active_collection()) end)
      :ok
    end

    test "it uses a featured item banner image fallback", %{conn: conn} do
      conn
      |> visit("/collections/middle-east-mss")
      |> assert_has(".phx-connected")
      # Title
      |> assert_has("h1", text: "Middle East Manuscripts")
      # Banner image area
      |> assert_has("#collection-banner", count: 1)
      # Banner item link
      |> assert_has(
        "#collection-banner a[href='/i/work-botany-arabic/item/159ba3f9-feab-49dd-bc71-ca08995006d9']"
      )
      # Banner image
      |> assert_has(
        "#collection-banner img[src='https://iiif-cloud.princeton.edu/iiif/2/63%2Fc9%2Ff8%2F63c9f84fc5314a19aef8a2d54f468267%2Fintermediate_file/full/!453,800/0/default.jpg']"
      )
    end
  end

  describe "a collection with related collections" do
    setup do
      with_mock DpulCollections.IndexingPipeline.Figgy.HydrationConsumer, [:passthrough],
        process?: fn _ -> true end do
        [
          # Manuscripts of the Islamic World collection
          "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
          # Middle East Manuscripts collection
          "3bab572e-6603-4abf-8305-16ce6fe3ac5c",
          # Robert Garrett collection
          "3b230de6-e7d3-4482-8f19-d76c8491cec3",
          # Collections Donated to Princeton University Library
          "62339f65-ce6d-4c85-ab77-67c70abb8709",
          # featured item, it's in 4 collections (but more could be added to the
          # CSV since it's a synthetic fixture)
          "159ba3f9-feab-49dd-bc71-ca08995006d9"
        ]
        |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)
      end

      Solr.soft_commit(active_collection())
      on_exit(fn -> Solr.delete_all(active_collection()) end)
      :ok
    end

    test "it has content for the collection", %{conn: conn} do
      conn
      |> visit("/collections/islamicmss")
      |> assert_has(".phx-connected")
      # Featured Highlights are initially visible
      |> assert_has("#featured-items .browse-item")
      |> refute_has("#related-collection-62339f65-ce6d-4c85-ab77-67c70abb8709")
      |> Playwright.click("#related-collections-tab")
      # Now Related collections are visible
      |> refute_has("#featured-items .browse-item")
      # Related Collections card with banner in fixture has an image
      |> within("#related-collection-62339f65-ce6d-4c85-ab77-67c70abb8709", fn session ->
        session
        |> assert_has("img")
        |> assert_has("div", text: "Collections Donated to Princeton")
        |> assert_has(".brief-metadata", text: "People donate some pretty interesting things")
      end)
      # Related Collections card with a featured item but no banner in fixture has an image
      # long tagline is truncated
      |> within("#related-collection-3bab572e-6603-4abf-8305-16ce6fe3ac5c", fn session ->
        session
        |> assert_has("img")
        |> assert_has("div", text: "Middle East Manuscripts")
        |> refute_has(".brief-metadata", text: "and digitization")
        |> assert_has(".brief-metadata", text: "...")
      end)

      # TODO click on the arrow and assert that 
      # link to related collections search result page
      # see #1284
      # |> assert_has(
      #   "a[href='search?filter[related_collections][]=Russian+and+East+European+Posters']"
      # )
    end
  end

  describe "a collection whose related collection has neither banner nor featured items" do
    setup do
      with_mock DpulCollections.IndexingPipeline.Figgy.HydrationConsumer, [:passthrough],
        process?: fn _ -> true end do
        [
          # Manuscripts of the Islamic World collection
          "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
          # Middle East Manuscripts collection
          "3bab572e-6603-4abf-8305-16ce6fe3ac5c",
          # an item they have in common that's not featured
          "2cc9b5cf-8d33-4f1b-b53f-fcc658770458"
        ]
        |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)
      end

      Solr.soft_commit(active_collection())
      on_exit(fn -> Solr.delete_all(active_collection()) end)
      :ok
    end

    test "the related collection card renders", %{conn: conn} do
      conn
      |> visit("/collections/islamicmss")
      |> assert_has(".phx-connected")
      |> Playwright.click("#related-collections-tab")
      # Now Related collections are visible
      |> refute_has("#featured-items .browse-item")
      # Related Collections card with banner in fixture has an image
      |> within("#related-collection-3bab572e-6603-4abf-8305-16ce6fe3ac5c", fn session ->
        session
        |> assert_has("div", text: "Middle East Manuscripts")
      end)
    end
  end
end
