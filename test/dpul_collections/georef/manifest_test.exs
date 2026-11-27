defmodule DpulCollections.Georef.ManifestTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.Manifest
  alias DpulCollections.Georef.Manifest.Canvas

  defp canvas(id, label, service) do
    %{
      "id" => id,
      "type" => "Canvas",
      "label" => label,
      "width" => 6000,
      "height" => 7000,
      "items" => [
        %{
          "type" => "AnnotationPage",
          "items" => [
            %{
              "type" => "Annotation",
              "motivation" => "painting",
              "body" => %{"id" => "#{id}/full.jpg", "type" => "Image", "service" => service}
            }
          ]
        }
      ]
    }
  end

  defp manifest do
    %{
      "id" => "https://figgy.example.org/concern/scanned_maps/abc/manifest",
      "type" => "Manifest",
      "label" => %{"eng" => ["Insurance maps of Palmyra, New Jersey"]},
      "navPlace" => %{
        "type" => "FeatureCollection",
        "features" => [
          %{
            "type" => "Feature",
            "geometry" => %{
              "type" => "Polygon",
              "coordinates" => [
                [[-75.04, 40.0], [-75.02, 40.0], [-75.02, 40.01], [-75.04, 40.01], [-75.04, 40.0]]
              ]
            }
          },
          %{
            "type" => "Feature",
            "geometry" => %{"type" => "Point", "coordinates" => [-75.05, 40.02]}
          }
        ]
      },
      "metadata" => [
        %{"label" => %{"eng" => ["Creator"]}, "value" => %{"eng" => ["Sanborn Map Company"]}},
        %{
          "label" => %{"eng" => ["Subject"]},
          "value" => %{
            "eng" => [
              "Real property—New Jersey—Palmyra—Maps",
              "Real property—New Jersey—Burlington County—Maps",
              "Fire insurance—New Jersey—Palmyra",
              "Sanborn maps"
            ]
          }
        },
        %{"value" => %{"eng" => ["no label"]}}
      ],
      "items" => [
        canvas("https://figgy.example.org/c1", %{"eng" => ["Sheet 1"]}, [
          %{"@id" => "https://iiif.example.org/c1", "@type" => "ImageService2"}
        ]),
        canvas("https://figgy.example.org/c2", %{"none" => ["Sheet 2"]}, [
          %{"id" => "https://iiif.example.org/c2", "type" => "ImageService3"}
        ]),
        Map.delete(canvas("https://figgy.example.org/c3", nil, nil), "label")
        |> put_in(["items", Access.at(0), "items", Access.at(0), "body"], %{"type" => "Image"})
      ]
    }
  end

  describe "parse/1" do
    test "pulls the label, navPlace bbox, subject places and canvases" do
      m = Manifest.parse(manifest())

      assert m.id == manifest()["id"]
      assert m.label == "Insurance maps of Palmyra, New Jersey"
      assert m.bbox == {-75.05, 40.0, -75.02, 40.02}
      # county subjects and non-place subjects are left out; repeats collapse
      assert m.subject_places == ["Palmyra"]

      assert [
               %Canvas{
                 id: "https://figgy.example.org/c1",
                 label: "Sheet 1",
                 width: 6000,
                 height: 7000,
                 service_id: "https://iiif.example.org/c1"
               },
               %Canvas{label: "Sheet 2", service_id: "https://iiif.example.org/c2"},
               %Canvas{id: "https://figgy.example.org/c3", label: nil, service_id: nil}
             ] = m.canvases
    end

    test "a bare manifest has no bbox, places or canvases" do
      assert Manifest.parse(%{"id" => "m"}) == %Manifest{
               id: "m",
               label: nil,
               bbox: nil,
               subject_places: [],
               canvases: []
             }
    end
  end

  describe "fetch/1" do
    test "says which manifest failed and how" do
      Req.Test.stub(DpulCollections.Georef, &Plug.Conn.send_resp(&1, 404, "gone"))

      assert_raise RuntimeError,
                   "manifest fetch failed for https://example.org/m: HTTP 404",
                   fn ->
                     Manifest.fetch("https://example.org/m")
                   end
    end

    test "fetches and parses a manifest" do
      Req.Test.stub(DpulCollections.Georef, fn conn ->
        assert conn.request_path == "/concern/scanned_maps/abc/manifest"
        Req.Test.json(conn, manifest())
      end)

      m = Manifest.fetch(manifest()["id"])
      assert m.label == "Insurance maps of Palmyra, New Jersey"
      assert length(m.canvases) == 3
    end
  end
end
