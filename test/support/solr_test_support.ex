defmodule SolrTestSupport do
  def mock_solr_documents(count \\ 100, embed_manifest \\ false) do
    for n <- 1..count do
      date = 2025 - n

      # Equals the number of image service urls
      file_count = 7

      # Assign thumbnail urls to even numbered documents.
      # Used for testing thumbnail rendering order
      thumbnail_url =
        cond do
          rem(n, 2) == 0 -> "https://example.com/iiif/2/image2"
          true -> nil
        end

      # Even numbered documents are folders.
      genre =
        cond do
          rem(n, 2) == 0 -> ["Folders"]
          true -> ["Pamphlets"]
        end

      manifest_url =
        case embed_manifest do
          false ->
            "https://example.com/#{n}/manifest"

          # Content state encode a simple IIIF manifest.
          true ->
            TestServer.start()
            "#{TestServer.url()}/manifest/#{n}/manifest"
        end

      %{
        id: n,
        title_txtm: "Document-#{n}",
        display_date_s: date |> Integer.to_string(),
        years_is: [date],
        file_count_i: file_count,
        image_service_urls_ss: [
          "https://example.com/iiif/2/image1",
          "https://example.com/iiif/2/image2",
          "https://example.com/iiif/2/image3",
          "https://example.com/iiif/2/image4",
          "https://example.com/iiif/2/image5",
          "https://example.com/iiif/2/image6",
          "https://example.com/iiif/2/image7"
        ],
        image_canvas_ids_ss: [
          "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1",
          "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
        ],
        genre_txtm: genre,
        primary_thumbnail_service_url_s: thumbnail_url,
        iiif_manifest_url_s: manifest_url,
        digitized_at_dt:
          DateTime.utc_now() |> DateTime.add(-100 + 1 * n, :day) |> DateTime.to_iso8601()
      }
    end
  end

  def stub_manifest(n) do
    url = "#{TestServer.url()}/manifest/#{n}/manifest"
    TestServer.add("/manifest/#{n}/manifest", via: :get, to: &manifest_response(&1, url))
  end

  def manifest_response(conn, url) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.merge_resp_headers([
      {"access-control-allow-origin", "*"},
      {"access-control-allow-methods", "GET"}
    ])
    |> Plug.Conn.delete_resp_header("Vary")
    |> Plug.Conn.delete_resp_header("Content-Encoding")
    |> Plug.Conn.resp(200, Jason.encode!(simple_manifest(url)))
  end

  def simple_manifest(url) do
    %{
      "@context" => "http://iiif.io/api/presentation/3/context.json",
      "id" => url,
      "type" => "Manifest",
      "label" => %{
        "en" => [
          "Two Image Example"
        ]
      },
      "items" => [
        %{
          "id" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1",
          "type" => "Canvas",
          "height" => 1800,
          "width" => 1200,
          "items" => [
            %{
              "id" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/page/p1/1",
              "type" => "AnnotationPage",
              "items" => [
                %{
                  "id" =>
                    "https://iiif.io/api/cookbook/recipe/0001-mvm-image/annotation/p0001-image",
                  "type" => "Annotation",
                  "motivation" => "painting",
                  "body" => %{
                    "id" =>
                      "http://iiif.io/api/presentation/2.1/example/fixtures/resources/page1-full.png",
                    "type" => "Image",
                    "format" => "image/png",
                    "height" => 1800,
                    "width" => 1200
                  },
                  "target" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1"
                }
              ]
            }
          ]
        },
        %{
          "id" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2",
          "type" => "Canvas",
          "height" => 1800,
          "width" => 1200,
          "items" => [
            %{
              "id" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/page/p1/2",
              "type" => "AnnotationPage",
              "items" => [
                %{
                  "id" =>
                    "https://iiif.io/api/cookbook/recipe/0001-mvm-image/annotation/p0001-image-2",
                  "type" => "Annotation",
                  "motivation" => "painting",
                  "body" => %{
                    "id" =>
                      "http://iiif.io/api/presentation/2.1/example/fixtures/resources/page1-full.png",
                    "type" => "Image",
                    "format" => "image/png",
                    "height" => 1800,
                    "width" => 1200
                  },
                  "target" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
                }
              ]
            }
          ]
        }
      ]
    }
  end

  # In most tests we can read and write to the same collection,
  # we'll call it the active collection
  def active_collection do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end
end
