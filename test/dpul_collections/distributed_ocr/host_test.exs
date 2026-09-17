defmodule DpulCollections.DistributedOcr.HostTest do
  use DpulCollections.DataCase
  alias DpulCollections.DistributedOcr.Host
  alias DpulCollections.Solr

  setup do
    sham =
      Sham.start()
      |> Sham.stub("GET", "/manifest/1/manifest", &manifest_stub/1)

    Solr.add(SolrTestSupport.mock_solr_documents(1, true, sham), active_collection())
    Solr.soft_commit(active_collection())
    {:ok, sham: sham}
  end

  describe ".ocr_manifest/1" do
    test "requests OCR of every page", %{sham: sham} do
      Host.ocr_manifest("http://localhost:#{sham.port}/manifest/1/manifest")

      {:ok, page} = Host.fetch_job()

      assert page ==
               "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/1000,/0/default.jpg"
    end
  end

  def manifest_stub(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.merge_resp_headers([
      {"access-control-allow-origin", "*"},
      {"access-control-allow-methods", "GET"}
    ])
    |> Plug.Conn.delete_resp_header("Vary")
    |> Plug.Conn.delete_resp_header("Content-Encoding")
    |> Plug.Conn.resp(200, JSON.encode!(fake_manifest()))
  end

  def fake_manifest() do
    """
    {
    "@context": "http://iiif.io/api/presentation/2/context.json",
    "@type": "sc:Manifest",
    "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest",
    "label": "Test",
    "viewingHint": "individuals",
    "metadata": [
    {
      "label": "Title",
      "value": [
        "Test"
      ]
    },
    {
      "label": "Embargo Date",
      "value": [
        ""
      ]
    }
    ],
    "sequences": [
    {
      "@type": "sc:Sequence",
      "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/sequence/normal",
      "rendering": [
        {
          "@id": "https://figgy-staging.princeton.edu/catalog/eef217c2-bee1-4903-a5d8-9da430a08940/pdf",
          "label": "Download as PDF",
          "format": "application/pdf"
        }
      ],
      "canvases": [
        {
          "@type": "sc:Canvas",
          "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/canvas/07269645-02b1-4720-b99e-065aa9fb0887",
          "label": "default (11).jpg",
          "thumbnail": {
            "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/!200,150/0/default.jpg",
            "service": {
              "@context": "http://iiif.io/api/image/2/context.json",
              "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
              "profile": "http://iiif.io/api/image/2/level2.json"
            }
          },
          "rendering": [
            {
              "@id": "https://figgy-staging.princeton.edu/downloads/07269645-02b1-4720-b99e-065aa9fb0887/file/91fd958a-e01e-4c6b-86d4-ceaf6cd0da98",
              "label": "Download the original file",
              "format": "image/jpeg"
            }
          ],
          "width": 1000,
          "height": 1380,
          "images": [
            {
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "resource": {
                "@type": "dctypes:Image",
                "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/1000,/0/default.jpg",
                "height": 1380,
                "width": 1000,
                "format": "image/jpeg",
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
                  "profile": "http://iiif.io/api/image/2/level2.json"
                }
              },
              "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/image/07269645-02b1-4720-b99e-065aa9fb0887",
              "on": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/canvas/07269645-02b1-4720-b99e-065aa9fb0887"
            }
          ]
        }
      ],
      "viewingHint": "individuals"
    }
    ],
    "structures": [
    {
      "@type": "sc:Range",
      "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/range/r8d5ce632-6be3-4f88-b951-de9a56b87509",
      "label": "Logical",
      "viewingHint": "top",
      "ranges": [],
      "canvases": []
    }
    ],
    "seeAlso": {
    "@id": "https://figgy-staging.princeton.edu/catalog/eef217c2-bee1-4903-a5d8-9da430a08940.jsonld",
    "format": "application/ld+json"
    },
    "license": "http://rightsstatements.org/vocab/CNE/1.0/",
    "thumbnail": {
    "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/!200,150/0/default.jpg",
    "service": {
      "@context": "http://iiif.io/api/image/2/context.json",
      "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
      "profile": "http://iiif.io/api/image/2/level2.json"
    }
    },
    "logo": "https://figgy-staging.princeton.edu/pul_logo_icon.png"
    }
    """
  end
end
