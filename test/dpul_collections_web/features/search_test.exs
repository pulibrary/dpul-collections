defmodule DpulCollectionsWeb.Features.SearchTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "image counts are shown when total files outnumber visible images", %{conn: conn} do
    conn
    |> visit("/search?q=")
    # when filecount exceeds visible images show image total
    |> assert_has("#item-1", text: "Document-1")
    # when visible images equals filecount don't show image total
    |> assert_has("#filecount-1", text: "7 Images")
  end

  test "when there's a content warning, thumbnails are obfuscated", %{conn: conn} do
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

    Solr.commit()

    conn
    |> visit("/search?q=elham+azar")
    |> assert_has("img.obfuscate")

    # an item without a content warning isn't obfuscated
    conn
    |> visit("/search?q=Document")
    |> refute_has("img.obfuscate")
  end
end
