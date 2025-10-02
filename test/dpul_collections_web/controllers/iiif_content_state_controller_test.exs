defmodule DpulCollectionsWeb.IiifContentStateControllerTest do
  use DpulCollectionsWeb.ConnCase
  alias DpulCollections.Solr

  setup do
    Solr.add([
      %{
        id: 1,
        title_txtm: "زلزلہ",
        display_date_s: "2024",
        file_count_i: 1,
        iiif_manifest_url_s: "https://example.com/manifest/1",
        image_service_urls_ss: [
          "https://example.com/iiif/1/image1"
        ],
        image_canvas_ids_ss: ["https://example.com/manifest/1/canvas/1"],
        primary_thumbnail_service_url_s: "https://example.com/iiif/1/image1"
      },
      %{
        id: 2,
        title_txtm: "اب كوئى جنگ نه هوگى نه كبهى رات گئے، خون كى آگ كو اشكوں سے بجهانا هوگا",
        display_date_s: "2022",
        file_count_i: 1,
        image_service_urls_ss: [
          "https://example.com/iiif/2/image1"
        ],
        primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1"
      }
    ])

    Solr.soft_commit(active_collection())
    :ok
  end

  describe "show/2" do
    test "returns a valid IIIF content state JSON when given a valid ID and canvas index", %{
      conn: conn
    } do
      conn = get(conn, ~p"/iiif/1/content_state/1")

      # Assert the response
      assert json_response(conn, 200) == %{
               "@context" => "http://iiif.io/api/presentation/3/context.json",
               "id" => "http://localhost:4002/iiif/1/content_state/1",
               "type" => "Annotation",
               "motivation" => ["contentState"],
               "target" => %{
                 "id" => "https://example.com/manifest/1/canvas/1",
                 "type" => "Canvas",
                 "partOf" => [
                   %{
                     "id" => "https://example.com/manifest/1",
                     "type" => "Manifest"
                   }
                 ]
               }
             }
    end

    test "returns a 400 error when given an invalid canvas index", %{conn: conn} do
      conn = get(conn, ~p"/iiif/1/content_state/invalid")
      assert json_response(conn, 400) == %{"error" => "Invalid canvas index"}
    end

    test "returns a 404 error when the item is not found", %{conn: conn} do
      conn = get(conn, ~p"/iiif/non-existent-id/content_state/1")
      assert json_response(conn, 404) == %{"error" => "Item not found"}
    end

    test "returns a 404 error when the canvas is not found", %{conn: conn} do
      conn = get(conn, ~p"/iiif/2/content_state/1")
      assert json_response(conn, 404) == %{"error" => "Canvas not found"}
    end
  end
end
