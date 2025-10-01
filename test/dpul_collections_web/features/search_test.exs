defmodule DpulCollectionsWeb.Features.SearchTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr

  test "image counts are shown when total files outnumber visible images", %{conn: conn} do
    Solr.add(
      [
        %{
          id: 1,
          title_txtm: ["Document-1"],
          display_date_s: "2025",
          years_is: [2025],
          file_count_i: 8,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2",
            "https://example.com/iiif/2/image3",
            "https://example.com/iiif/2/image4",
            "https://example.com/iiif/2/image5",
            "https://example.com/iiif/2/image6",
            "https://example.com/iiif/2/image7",
            "https://example.com/iiif/2/image8"
          ],
          image_canvas_ids_ss: [
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1",
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
          ],
          genre_txt_sort: "Ephemera",
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image2"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())

    conn
    |> visit("/search?q=")
    # when filecount exceeds visible images show image total
    |> assert_has("#item-1", text: "Document-1")
    # when visible images equals filecount don't show image total
    |> assert_has("#filecount-1", text: "8 Images")
  end
end
