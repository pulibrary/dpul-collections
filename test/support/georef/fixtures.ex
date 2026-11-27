defmodule DpulCollections.GeorefFixtures do
  @moduledoc """
  Georeferencer test helpers: run `Osm` against a fresh cache dir and a copy of
  `test/support/georef/fake_osmium` that serves the given features instead of the
  Palmyra fixtures. They change application env, so tests using them must be
  `async: false`; the previous settings are restored on exit.
  """

  @fake_osmium Path.expand("fake_osmium", __DIR__)

  @doc """
  `fixtures`: %{"streets" | "buildings" | "places" => [geojson feature map]}
  (a missing kind is an empty extract).
  """
  def with_osm_fixtures(fixtures) do
    root = Path.join(System.tmp_dir!(), "georef_fixture_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "fixtures"))
    osmium = Path.join(root, "fake_osmium")
    File.cp!(@fake_osmium, osmium)
    File.chmod!(osmium, 0o755)

    for kind <- ~w(streets buildings places) do
      File.write!(
        Path.join(root, "fixtures/#{kind}.geojsonseq"),
        fixtures |> Map.get(kind, []) |> Enum.map_join(&(Jason.encode!(&1) <> "\n"))
      )
    end

    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(root) end)
    put_georef_config(cache_dir: Path.join(root, "cache"), osmium: osmium)
    root
  end

  @doc "Override `DpulCollections.Georef` settings for this test."
  def put_georef_config(opts) do
    old = Application.get_env(:dpul_collections, DpulCollections.Georef, [])
    Application.put_env(:dpul_collections, DpulCollections.Georef, Keyword.merge(old, opts))

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:dpul_collections, DpulCollections.Georef, old)
    end)
  end

  def feature(type, coordinates, properties) do
    %{
      "type" => "Feature",
      "geometry" => %{"type" => type, "coordinates" => coordinates},
      "properties" => properties
    }
  end
end
