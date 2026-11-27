defmodule DpulCollections.Georef.OsmFixturesTest do
  # Swaps the georef cache dir and osmium command in application env.
  use ExUnit.Case, async: false

  import DpulCollections.GeorefFixtures

  alias DpulCollections.Georef
  alias DpulCollections.Georef.Osm

  @bbox {-75.0, 40.0, -74.99, 40.01}

  defp line(coords, props), do: feature("LineString", coords, props)

  defp square(x, y, d),
    do: [[x - d, y - d], [x + d, y - d], [x + d, y + d], [x - d, y + d], [x - d, y - d]]

  describe "load/1" do
    setup do
      with_osm_fixtures(%{
        "streets" => [
          # one way with several names: each name is a key
          line([[-75.0, 40.005], [-74.99, 40.005]], %{
            "highway" => "residential",
            "name" => "Main Street;Kings Highway",
            "old_name" => "Front Street"
          }),
          # Church Street in two ways meeting on Main: one crossing, not two
          line([[-74.997, 40.0], [-74.997, 40.005]], %{
            "highway" => "residential",
            "name" => "Church Street"
          }),
          line([[-74.997, 40.005], [-74.997, 40.01]], %{
            "highway" => "residential",
            "name" => "Church Street"
          }),
          line([[-74.993, 40.0], [-74.993, 40.01]], %{
            "waterway" => "stream",
            "name" => "Mill Creek"
          }),
          # not streets, rails or waters worth reading
          line([[-74.995, 40.0], [-74.995, 40.01]], %{
            "railway" => "platform",
            "name" => "Platform"
          }),
          line([[-74.994, 40.0], [-74.994, 40.01]], %{"waterway" => "dam", "name" => "Dam"}),
          line([[-74.996, 40.0], [-74.996, 40.01]], %{"highway" => "footway"}),
          feature("MultiLineString", [[[-74.99, 40.0], [-74.99, 40.01]]], %{
            "highway" => "residential",
            "name" => "Multi Street"
          })
        ],
        "buildings" => [
          feature("Polygon", [square(-74.996, 40.005, 0.0002)], %{
            "building" => "church",
            "name" => "Grace Lutheran Church"
          }),
          feature(
            "MultiPolygon",
            [
              [square(-74.998, 40.002, 0.0002)],
              # a degenerate ring is skipped
              [[[-74.998, 40.003], [-74.997, 40.003], [-74.998, 40.003]]]
            ],
            %{"building" => "industrial", "name" => "Riverside Mill"}
          ),
          # generic, too short, empty, unnamed: say nothing about which building
          feature("Polygon", [square(-74.992, 40.002, 0.0002)], %{"name" => "Garage"}),
          feature("Polygon", [square(-74.992, 40.003, 0.0002)], %{"name" => "Hut"}),
          feature("Polygon", [square(-74.992, 40.004, 0.0002)], %{"name" => "!!"}),
          feature("Polygon", [square(-74.992, 40.006, 0.0002)], %{"building" => "yes"}),
          # a street of the same name wins
          feature("Polygon", [square(-74.993, 40.008, 0.0002)], %{"name" => "Mill Creek"})
        ]
      })

      %{osm: Osm.load(@bbox)}
    end

    test "builds features from every name of streets, rails and waterways", %{osm: osm} do
      assert Enum.sort(Map.keys(osm.groups)) ==
               Enum.sort([
                 "main",
                 "kings",
                 "front",
                 "church",
                 "mill creek",
                 "grace lutheran church",
                 "riverside mill"
               ])

      assert %{label: "Main Street", kind: :street} = osm.groups["main"]
      assert osm.groups["kings"].segments == osm.groups["main"].segments
      assert %{kind: :water, label: "Mill Creek", polygons: nil} = osm.groups["mill creek"]
      assert length(osm.groups["church"].segments) == 2

      assert %{kind: :building, polygons: [ring]} = osm.groups["grace lutheran church"]
      assert length(ring) == 4
      assert %{polygons: [_]} = osm.groups["riverside mill"]
    end

    test "one intersection per crossing street pair, none with buildings", %{osm: osm} do
      pairs = osm.intersections |> Enum.map(& &1.keys) |> Enum.sort()

      assert pairs ==
               Enum.sort([
                 {"church", "main"},
                 {"church", "kings"},
                 {"church", "front"},
                 {"main", "mill creek"},
                 {"kings", "mill creek"},
                 {"front", "mill creek"}
               ])

      [%{lonlat: [lon, lat]}] = Enum.filter(osm.intersections, &(&1.keys == {"church", "main"}))
      assert_in_delta lon, -74.997, 1.0e-9
      assert_in_delta lat, 40.005, 1.0e-9
    end
  end

  describe "find_place/1" do
    test "ranks cities first and unknown place types last" do
      with_osm_fixtures(%{
        "places" => [
          feature("Point", [-75.2, 39.8], %{"name" => "Camden", "place" => "locality"}),
          feature("Point", [-75.0, 39.9], %{"name" => "Camden", "place" => "town"}),
          feature("Point", [-75.12, 39.94], %{"name" => "Camden", "place" => "city"}),
          feature("Point", [-75.0, 39.0], %{"place" => "village"})
        ]
      })

      assert Enum.map(Osm.find_place("Camden"), & &1.place) == ["city", "town", "locality"]
    end
  end

  describe "osmium failures" do
    setup do
      put_georef_config(
        cache_dir:
          Path.join(System.tmp_dir!(), "georef_fail_#{System.unique_integer([:positive])}"),
        osmium: "false"
      )

      on_exit(fn -> File.rm_rf!(Georef.cache_dir()) end)
    end

    test "load/1 raises when the extract fails" do
      assert_raise RuntimeError, ~r/osmium extract failed \(1\)/, fn -> Osm.load(@bbox) end
    end

    test "find_place/1 raises when the place filter fails" do
      assert_raise RuntimeError, ~r/osmium tags-filter failed/, fn -> Osm.find_place("Camden") end
    end
  end

  test "pbf_path defaults to the state extract in the cache dir" do
    put_georef_config(cache_dir: "/tmp/georef-cache")
    assert Osm.pbf_path() == "/tmp/georef-cache/new-jersey-latest.osm.pbf"
    put_georef_config(osm_pbf: "/data/nj.osm.pbf")
    assert Osm.pbf_path() == "/data/nj.osm.pbf"
  end

  describe "Georef.search_bbox/1 for a city" do
    test "searches ~13 km around a city with no catalog bbox" do
      with_osm_fixtures(%{
        "places" => [feature("Point", [-75.12, 39.94], %{"name" => "Camden", "place" => "city"})]
      })

      {a, b, c, d} =
        Georef.search_bbox(%{label: "Insurance maps of Camden, New Jersey", bbox: nil})

      assert_in_delta a, -75.2, 1.0e-9
      assert_in_delta b, 39.88, 1.0e-9
      assert_in_delta c, -75.04, 1.0e-9
      assert_in_delta d, 40.0, 1.0e-9
    end
  end
end
