defmodule DpulCollectionsWeb.Features.ContentWarningsTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
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
          ]
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "when there's a content warning, thumbnails are obfuscated", %{conn: conn} do
    # an item without a content warning isn't obfuscated
    conn
    |> visit("/search?q=Document")
    |> refute_has("img.obfuscate")

    # an item with a content warning is obfuscated
    conn
    |> visit("/search?q=elham+azar")
    |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 3)
    |> assert_has("img.obfuscate", count: 3)
    |> click_button("Show images")
    |> refute_has("img.obfuscate")

    # the item is obfuscated on a standard browse page
    conn
    |> visit("/browse")
    |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 3)
    |> assert_has("img.obfuscate", count: 3)
    |> click_button("Show images")
    |> refute_has("img.obfuscate")

    # the item is obfuscated on its own focused browse page
    conn
    |> visit("/browse/focus/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
    # the tiny thumbnail in the toolbar is also obfuscated
    |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 4)
    |> assert_has("img.obfuscate", count: 4)
    |> click_button("Show images")
    |> refute_has("img.obfuscate")

    # the item its obfuscated on its item detail page
    conn
    |> visit("/item/d4292e58-25d7-4247-bf92-0a5e24ec75d1")
    # the large thumbnail is duplicated in the small thumbnail list
    |> assert_has(".thumbnail-d4292e58-25d7-4247-bf92-0a5e24ec75d1", count: 4)
    |> assert_has("img.obfuscate", count: 4)
    |> click_button("Show images")
    |> refute_has("img.obfuscate")
  end
end
