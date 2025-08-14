defmodule DpulCollectionsWeb.Features.ContentWarningsTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias PhoenixTest.Playwright.Frame
  alias DpulCollections.Solr

  setup_all do
    Solr.add(SolrTestSupport.mock_solr_documents(50), active_collection())

    Solr.add(
      [
        %{
          id: "d4292e58-25d7-4247-bf92-0a5e24ec75d1",
          title_txtm: ["Elham Azar"],
          content_warning_s: "This item depicts images that may be harmful in this specific way.",
          file_count_i: 3,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2",
            "https://example.com/iiif/2/image3"
          ],
          updated_at_dt: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  describe "when there's a content warning, thumbnails are obfuscated" do
    test "on the home page", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("img.obfuscate", count: 3)
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
      |> refute_has(".browse-header")
    end

    test "on the search page", %{conn: conn} do
      # an item without a content warning isn't obfuscated
      conn
      |> visit("/search?q=Document")
      |> refute_has("img.obfuscate")

      # an item with a content warning is obfuscated
      conn
      |> visit("/search?q=elham+azar")
      |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 3)
      |> assert_has("img.obfuscate", count: 3)
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
    end

    test "on the standardbrowse page", %{conn: conn} do
      conn
      |> visit("/browse")
      |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 3)
      |> assert_has("img.obfuscate", count: 3)
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
    end

    test "on the focused browse page", %{conn: conn} do
      conn
      |> visit("/browse/focus/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
      # the tiny thumbnail in the toolbar is also obfuscated
      |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 4)
      |> assert_has("img.obfuscate", count: 4)
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
      |> refute_has("a", text: "Why are the images blurred?")
    end

    test "on the item detail page", %{conn: conn} do
      conn
      |> visit("/item/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
      # the large thumbnail is duplicated in the small thumbnail list
      |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 4)
      |> assert_has("img.obfuscate", count: 4)
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
      # Make sure the viewer also knows not to render this.
      |> click_link("#viewer-link", "View")
      |> refute_has("h2", text: "Content Warning")
    end

    test "in the viewer", %{conn: conn} do
      conn
      |> visit("/item/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
      |> click_link("#viewer-link", "View")
      # the large thumbnail is duplicated in the small thumbnail list
      |> assert_has("h2", text: "Content Warning")
      |> click_button("View content")
      |> refute_has("h2", text: "Content Warning")
    end
  end

  describe "once images have been shown on one page" do
    test "they are still shown after reload, and on other pages", %{conn: conn} do
      conn
      |> visit("/search?q=elham+azar")
      |> assert_has("img.obfuscate")
      |> click_link("Why are the images blurred?")
      |> click_button("View content")
      |> refute_has("img.obfuscate")
      |> unwrap(&Frame.evaluate(&1.frame_id, "window.location.reload()"))
      |> refute_has("img.obfuscate")
      |> visit("/item/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
      |> refute_has("img.obfuscate")
      |> visit("/browse")
      |> refute_has("img.obfuscate")
      |> visit("/browse/focus/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
      |> refute_has("img.obfuscate")
    end
  end
end
