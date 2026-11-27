defmodule DpulCollections.Georef.OsmTest do
  # Uses the default fake osmium (Palmyra fixtures) and the run's cache dir.
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.{Geometry, Osm}

  @palmyra {-75.034, 40.0, -75.024, 40.007}

  describe "load/1 (Palmyra fixtures)" do
    setup do
      %{osm: Osm.load(@palmyra)}
    end

    test "groups named streets, railways and buildings by normalized key", %{osm: osm} do
      assert osm.bbox == @palmyra
      assert osm.projection == Geometry.projection(@palmyra)
      assert File.exists?(osm.path)

      # several ways named West Broad Street merge into one group
      broad = osm.groups["broad"]
      assert %{key: "broad", kind: :street, label: "West Broad Street", polygons: nil} = broad
      assert length(broad.segments) > 5

      assert %{kind: :rail, label: "River Line"} = osm.groups["river line"]

      # named building footprints become polygon groups; unnamed ones are dropped
      fire = osm.groups["palmyra fire department"]
      assert %{kind: :building, label: "Palmyra Fire Department", polygons: [ring]} = fire
      assert length(ring) >= 4
      assert length(fire.segments) == length(ring)

      # unnamed footways and paths are not features
      refute Enum.any?(osm.features, &(&1.name == nil))
      assert Enum.count(osm.features, &(&1.kind == :building)) == 3
    end

    test "intersections of differently-named streets, in lon/lat and metres", %{osm: osm} do
      market_5th = Enum.filter(osm.intersections, &(&1.keys == {"5th", "market"}))
      assert [%{lonlat: [lon, lat], xy: xy}] = market_5th
      assert_in_delta lon, -75.03142, 1.0e-4
      assert_in_delta lat, 40.00013, 1.0e-4
      assert Geometry.to_xy(osm.projection, [lon, lat]) == xy

      # keys are ordered pairs of distinct names, never buildings
      for %{keys: {k1, k2}} <- osm.intersections do
        assert k1 < k2
        refute osm.groups[k1].kind == :building
        refute osm.groups[k2].kind == :building
      end
    end

    test "a second load reuses the cached extract", %{osm: osm} do
      mtime = File.stat!(osm.path).mtime
      again = Osm.load(@palmyra)
      assert again.path == osm.path
      assert File.stat!(again.path).mtime == mtime
      assert map_size(again.groups) == map_size(osm.groups)
    end
  end

  describe "find_place/1" do
    test "returns same-named places, largest place type first" do
      assert [village, hamlet] = Osm.find_place("palmyra")
      assert %{name: "Palmyra", place: "village", lonlat: [-75.0282271, 40.0070565]} = village
      assert %{name: "Palmyra", place: "hamlet"} = hamlet
      assert [%{name: "Riverton"}] = Osm.find_place("Riverton")
      assert Osm.find_place("Atlantis") == []
    end
  end

  describe "with_aliases/2" do
    defp osm do
      %Osm{
        groups: %{
          "kings highway" => %{
            key: "kings highway",
            kind: :street,
            segments: [{{0.0, -500.0}, {0.0, 500.0}}]
          },
          "church" => %{key: "church", kind: :street, segments: [{{-500.0, 0.0}, {500.0, 0.0}}]},
          "main" => %{key: "main", kind: :street, segments: [{{-500.0, 100.0}, {500.0, 100.0}}]}
        },
        intersections: [
          %{keys: {"church", "kings highway"}, xy: {0.0, 0.0}, lonlat: [0, 0]},
          %{keys: {"kings highway", "main"}, xy: {0.0, 100.0}, lonlat: [0, 1]}
        ]
      }
    end

    test "an alias replacing an existing name takes the street's place and crossings" do
      aliased = Osm.with_aliases(osm(), %{"main" => "kings highway"})

      assert aliased.groups["main"] == %{osm().groups["kings highway"] | key: "main"}
      # the old Main Street's crossings are gone; Kings Highway's are copied to the alias
      assert Enum.map(aliased.intersections, &{&1.keys, &1.xy}) == [
               {{"church", "kings highway"}, {0.0, 0.0}},
               {{"church", "main"}, {0.0, 0.0}}
             ]
    end

    test "ignores self-aliases and aliases to unknown streets" do
      assert Osm.with_aliases(osm(), %{"church" => "church", "elm" => "oak"}) == osm()
    end
  end

  describe "normalize/1" do
    test "unifies railroad and creek spellings" do
      assert Osm.normalize("Pennsylvania Rail Road") == "pennsylvania railroad"
      assert Osm.normalize("Reading Ry.") == "reading railroad"
      assert Osm.normalize("Pennsauken Crk.") == "pennsauken creek"
      assert Osm.normalize("St. Mary's Place") == "st marys"
      assert Osm.normalize("Twelfth St") == "12th"
    end
  end
end
