defmodule DpulCollections.Georef do
  @moduledoc """
  Server-side helpers for the browser georeferencer (see
  docs/tech/georeferencing.md): where an atlas's town is, and fetching sheet
  images. The georeferencing itself runs in volunteers' browsers
  (assets/js/georeferencer/), coordinated by `DpulCollections.Georef.Collab`.
  """
  require Logger

  alias DpulCollections.Georef.Osm

  @doc """
  Settings, from `config :dpul_collections, DpulCollections.Georef`:
  `:cache_dir` (sheet images, OSM extracts, OCR models; default
  `~/.cache/dpul_georef`), `:osm_pbf` (the state extract; default in the cache
  dir) and `:osmium` (the osmium command).
  """
  def config(key, default),
    do: Application.get_env(:dpul_collections, __MODULE__, []) |> Keyword.get(key, default)

  def cache_dir, do: config(:cache_dir, Path.expand("~/.cache/dpul_georef"))

  @doc "Extra Req options for outside requests (tests stub them with Req.Test)."
  def req_options, do: Application.get_env(:dpul_collections, :georef_req_options, [])

  @doc "A sheet image from its IIIF image service, cached on disk."
  def fetch_image(url) do
    dir = Path.join(cache_dir(), "img")
    File.mkdir_p!(dir)
    path = Path.join(dir, Base.encode16(:crypto.hash(:md5, url)) <> ".jpg")

    if File.exists?(path) do
      File.read!(path)
    else
      opts =
        Keyword.merge(
          [decode_body: false, receive_timeout: 120_000, retry: :transient, max_retries: 5],
          req_options()
        )

      case Req.get!(url, opts) do
        %{status: 200, body: body} ->
          # write-then-rename: a concurrent request must never read a half-written jpg
          tmp = "#{path}.#{System.unique_integer([:positive])}.tmp"
          File.write!(tmp, body)
          File.rename!(tmp, path)
          body

        %{status: status} ->
          raise "image fetch failed for #{url}: HTTP #{status}"
      end
    end
  end

  @doc """
  Where to look. The catalog bbox is a hint, not truth (Hightstown's points at
  Hamilton). Find the title's place name in OSM: if a same-named place lies in
  the padded catalog bbox use that bbox, otherwise use a box around the place.
  """
  def search_bbox(manifest) do
    meta = manifest.bbox && pad(manifest.bbox, 0.2)
    town = place_name(manifest)
    places = Osm.find_place(town, Osm.pbf_for_title(manifest.label))
    inside = meta && Enum.find(places, fn %{lonlat: [x, y]} -> inside?(meta, x, y) end)

    cond do
      # Some catalog boxes are county-sized (Camden 45 x 61 km); a box that
      # big multiplies same-named streets, so search around the town instead.
      inside && area(meta) > 2 * area(place_box(inside)) -> place_box(inside)
      inside -> at_least_town(meta)
      places != [] -> place_box(hd(places))
      meta -> at_least_town(meta)
      true -> raise "no location for #{inspect(manifest.label)}"
    end
    |> tap(fn b ->
      Logger.info("georef: search bbox #{inspect(b)} (#{town}: #{length(places)} places)")
    end)
  end

  @doc """
  The place to search: the title's town, unless the catalog subject names one
  other town (the present name: Roosevelt's 1912 atlas is Carteret today).
  """
  def place_name(manifest) do
    town = town_name(manifest)

    case Map.get(manifest, :subject_places, []) do
      [other] -> if Osm.normalize(other) == Osm.normalize(town), do: town, else: other
      _ -> town
    end
  end

  @doc "The title's place name (\"Insurance maps of\" removed)."
  def town_name(manifest) do
    manifest.label
    |> to_string()
    |> String.replace(~r/^\s*insurance maps? of\s+/i, "")
    # Library of Congress titles: "Sanborn Fire Insurance Map from Salem, Marion County, Oregon"
    |> String.replace(~r/^\s*sanborn fire insurance maps? from\s+/i, "")
    |> String.split([",", "[", ":"])
    |> hd()
    |> String.trim()
  end

  defp inside?({a, b, c, d}, x, y), do: x >= a and x <= c and y >= b and y <= d
  defp area({a, b, c, d}), do: (c - a) * (d - b)

  # Catalog boxes can be tighter than the atlas (Bound Brook's 4 km box clips
  # the Middlesex sheets next door): never search less than a town box.
  defp at_least_town({a, b, c, d}) do
    {x0, y0, x1, y1} = place_box([(a + c) / 2, (b + d) / 2])
    {min(a, x0), min(b, y0), max(c, x1), max(d, y1)}
  end

  # ~7 km around a town; a city atlas (Camden's shipyard sheets lie 4 km from
  # the city node) needs ~13 km.
  defp place_box(%{place: "city", lonlat: [x, y]}), do: {x - 0.08, y - 0.06, x + 0.08, y + 0.06}
  defp place_box(%{lonlat: lonlat}), do: place_box(lonlat)
  defp place_box([x, y]), do: {x - 0.04, y - 0.03, x + 0.04, y + 0.03}

  defp pad({a, b, c, d}, f) do
    {dx, dy} = {(c - a) * f, (d - b) * f}
    {a - dx, b - dy, c + dx, d + dy}
  end
end
