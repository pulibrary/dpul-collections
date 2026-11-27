defmodule DpulCollections.GeorefTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.{Annotation, Geometry, Manifest, Mask, Osm}

  describe "Geometry" do
    test "transform maps image pixels (y down) to metres (y north)" do
      t = %{a: 0.04, b: 0.0, tx: 100.0, ty: 200.0}
      assert Geometry.transform(t, {1000, 500}) == {140.0, 180.0}
    end

    test "segment intersection" do
      assert Geometry.segment_intersection({{0, 0}, {10, 0}}, {{5, -5}, {5, 5}}) == {5.0, 0.0}
      assert nil == Geometry.segment_intersection({{0, 0}, {10, 0}}, {{20, -5}, {20, 5}})
    end
  end

  describe "Osm.normalize/1" do
    test "a leading \"the\" is filler, and a bare THE names nothing" do
      assert Osm.normalize("The Terrace") == "terrace"
      assert Osm.normalize("The Plaza") == "plaza"
      assert Osm.normalize("THE") == ""
      assert Osm.normalize("Theodore Street") == "theodore"
    end

    test "drops suffixes, directionals and punctuation; unifies ordinals" do
      assert Osm.normalize("N. Delaware St.") == "delaware"
      assert Osm.normalize("South Commerce Street") == "commerce"
      assert Osm.normalize("Second Avenue") == "2nd"
      assert Osm.normalize("5TH ST.") == "5th"
      assert Osm.normalize("Mantua Creek") == "mantua creek"
      assert Osm.normalize("Penna. R. R.") == "penna railroad"
      # a bare directional street keeps its name
      assert Osm.normalize("West Street") == "west"
    end
  end

  describe "Mask.inside_polygon?/2" do
    test "handles concave polygons" do
      l_shape = [{0, 0}, {100, 0}, {100, 50}, {50, 50}, {50, 100}, {0, 100}]
      assert Mask.inside_polygon?({25, 75}, l_shape)
      assert Mask.inside_polygon?({75, 25}, l_shape)
      refute Mask.inside_polygon?({75, 75}, l_shape)
      assert Mask.area(l_shape) == 7500.0
      assert Mask.bbox(l_shape) == {0, 0, 100, 100}
    end
  end

  describe "Annotation" do
    test "builds a georeferencing annotation with an SvgSelector mask" do
      manifest = %{id: "https://example.org/m", label: "Town"}

      canvas = %{
        id: "https://example.org/m/c1",
        width: 100,
        height: 200,
        service_id: "https://example.org/iiif/c1"
      }

      a =
        Annotation.annotation(
          manifest,
          canvas,
          [{1, 2}, {99, 2}, {120, 198}, {-3, 198}],
          [%{px: {10.4, 20.6}, lonlat: [-75.1, 39.9], label: "outline"}],
          "https://example.org/m/georef/1"
        )

      assert a["motivation"] == "georeferencing"
      assert a["target"]["source"]["id"] == canvas.service_id
      assert a["target"]["source"]["width"] == 100
      assert [%{"id" => "https://example.org/m/c1"}] = a["target"]["source"]["partOf"]
      # mask points are clamped to the image
      assert a["target"]["selector"]["value"] =~ ~s(<polygon points="1,2 99,2 100,198 0,198" />)
      [f] = a["body"]["features"]
      assert f["properties"] == %{"resourceCoords" => [10, 21], "label" => "outline"}
      assert f["geometry"]["coordinates"] == [-75.1, 39.9]
    end
  end

  describe "Renames" do
    alias DpulCollections.Georef.Renames

    test "a printed name becomes an alias when its votes agree" do
      votes =
        [{"main", "kings highway"}, {"main", "kings highway"}, {"main", "kings highway"}] ++
          [{"church", "church"}, {"church", "church"}, {"elm", "oak"}]

      assert Renames.table(votes) == %{"main" => "kings highway"}
      # split votes stay out
      assert Renames.table([{"main", "a"}, {"main", "b"}, {"main", "a"}]) == %{}
    end

    test "an alias gets the street's segments and crossings" do
      osm = %Osm{
        groups: %{
          "kings highway" => %{
            key: "kings highway",
            kind: :street,
            segments: [{{0.0, -500.0}, {0.0, 500.0}}]
          },
          "church" => %{key: "church", kind: :street, segments: [{{-500.0, 0.0}, {500.0, 0.0}}]}
        },
        intersections: [%{keys: {"church", "kings highway"}, xy: {0.0, 0.0}, lonlat: [0, 0]}]
      }

      aliased = Osm.with_aliases(osm, %{"main" => "kings highway"})
      assert aliased.groups["main"].segments == osm.groups["kings highway"].segments
      assert Enum.any?(aliased.intersections, &(&1.keys == {"church", "main"}))
    end
  end

  describe "place_name/1" do
    defp titled(label, subjects) do
      Manifest.parse(%{
        "id" => "m",
        "label" => %{"eng" => [label]},
        "metadata" => [
          %{"label" => %{"eng" => ["Subject"]}, "value" => %{"eng" => subjects}}
        ]
      })
    end

    test "uses the catalog subject's present-day town when it differs (Roosevelt 1912 = Carteret)" do
      m =
        titled("Insurance maps of Roosevelt, Middlesex County, New Jersey", [
          "Real property—New Jersey—Carteret—Maps"
        ])

      assert m.subject_places == ["Carteret"]
      assert DpulCollections.Georef.place_name(m) == "Carteret"
    end

    test "keeps the title's town when the subject agrees or names several" do
      assert DpulCollections.Georef.place_name(
               titled("Insurance maps of Belmar, Monmouth County", [
                 "Real property—New Jersey—Belmar—Maps"
               ])
             ) == "Belmar"

      two = ["Real property—New Jersey—Avon—Maps", "Real property—New Jersey—Bradley Beach—Maps"]

      assert DpulCollections.Georef.place_name(
               titled("Insurance maps of Avon, Monmouth County", two)
             ) == "Avon"
    end
  end
end
