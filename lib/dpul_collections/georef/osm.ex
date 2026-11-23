defmodule DpulCollections.Georef.Osm do
  @moduledoc """
  Local OpenStreetMap gazetteer for a bounding box: named streets, railways and
  waterways, plus every point where two differently-named features meet.

  Data comes from a state `.osm.pbf` extract on disk, clipped with `osmium`
  (`devbox global add osmium-tool`). Nothing is fetched at query time.
  """

  alias DpulCollections.Georef.Geometry

  @name_tags ~w(name old_name alt_name official_name historic:name)

  @overpass_mirrors [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter"
  ]

  defstruct [:bbox, :projection, features: [], groups: %{}, intersections: []]

  def pbf_path do
    Application.get_env(:dpul_collections, DpulCollections.Georef, [])
    |> Keyword.get(:osm_pbf, Path.expand("~/.cache/dpul_georef/new-jersey-latest.osm.pbf"))
  end

  @doc "Load (and cache) the gazetteer for a {min_lon, min_lat, max_lon, max_lat} bbox."
  def load(bbox) do
    path = extract(bbox)
    projection = Geometry.projection(bbox)

    features =
      path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.flat_map(&to_features(&1, projection))
      |> Enum.to_list()

    groups =
      features
      |> Enum.flat_map(fn f -> Enum.map(f.keys, &{&1, f}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {key, fs} ->
        {key,
         %{
           key: key,
           label:
             fs
             |> Enum.map(& &1.name)
             |> Enum.frequencies()
             |> Enum.max_by(&elem(&1, 1))
             |> elem(0),
           kind: hd(fs).kind,
           segments: Enum.flat_map(fs, & &1.segments)
         }}
      end)

    %__MODULE__{
      bbox: bbox,
      projection: projection,
      features: features,
      groups: groups,
      intersections: intersections(groups, projection)
    }
  end

  defp extract({a, b, c, d} = bbox) do
    dir = Path.expand("~/.cache/dpul_georef/osm")
    File.mkdir_p!(dir)

    key =
      :crypto.hash(:md5, :erlang.term_to_binary(bbox)) |> Base.encode16() |> binary_part(0, 12)

    out = Path.join(dir, "#{key}.geojsonseq")

    unless File.exists?(out) do
      filt = Path.join(dir, "#{key}-filt.osm.pbf")

      clip =
        if File.exists?(pbf_path()) and File.stat!(pbf_path()).size > 0 do
          clip = Path.join(dir, "#{key}-clip.osm.pbf")
          bb = Enum.join([a, b, c, d], ",")

          osmium!([
            "extract",
            "-b",
            bb,
            pbf_path(),
            "-o",
            clip,
            "--overwrite",
            "-s",
            "complete_ways"
          ])

          clip
        else
          # No state extract on disk: fetch just this bbox once from Overpass
          # and cache it; everything downstream is still local.
          clip = Path.join(dir, "#{key}-clip.osm")
          fetch_overpass!(bbox, clip)
          clip
        end

      osmium!([
        "tags-filter",
        clip,
        "w/highway",
        "w/railway",
        "w/waterway",
        "-o",
        filt,
        "--overwrite"
      ])

      osmium!([
        "export",
        filt,
        "-f",
        "geojsonseq",
        "-x",
        "print_record_separator=false",
        "--geometry-types=linestring",
        "-o",
        out,
        "--overwrite"
      ])

      File.rm(clip)
      File.rm(filt)
    end

    out
  end

  defp fetch_overpass!({a, b, c, d}, path) do
    bb = Enum.join([b, a, d, c], ",")

    query =
      "[out:xml][timeout:180];(way[highway](#{bb});way[railway](#{bb});way[waterway](#{bb}););(._;>;);out body;"

    body =
      Enum.find_value(1..4, fn attempt ->
        Enum.find_value(@overpass_mirrors, fn url ->
          case Req.post(url,
                 form: [data: query],
                 receive_timeout: 240_000,
                 decode_body: false,
                 retry: false,
                 headers: [{"user-agent", "dpul-collections-georef-prototype"}]
               ) do
            {:ok, %{status: 200, body: "<?xml" <> _ = body}} ->
              body

            _ ->
              nil
          end
        end) || (Process.sleep(attempt * 5_000) && nil)
      end) || raise("all Overpass mirrors failed")

    File.write!(path, body)
  end

  @doc """
  Look up populated places by name in the local extract. Returns
  `[%{name, place, lonlat}]`, best (largest place type) first.
  """
  def find_place(name) do
    dir = Path.expand("~/.cache/dpul_georef/osm")
    File.mkdir_p!(dir)
    out = Path.join(dir, "places.geojsonseq")

    unless File.exists?(out) do
      filt = Path.join(dir, "places.osm.pbf")

      osmium!([
        "tags-filter",
        pbf_path(),
        "n/place=city,town,village,hamlet,suburb,borough",
        "-o",
        filt,
        "--overwrite"
      ])

      osmium!([
        "export",
        filt,
        "-f",
        "geojsonseq",
        "-x",
        "print_record_separator=false",
        "-o",
        out,
        "--overwrite"
      ])

      File.rm(filt)
    end

    key = normalize(name)

    rank = %{
      "city" => 0,
      "town" => 1,
      "borough" => 2,
      "village" => 3,
      "suburb" => 4,
      "hamlet" => 5
    }

    out
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.filter(fn f ->
      f["properties"]["name"] && normalize(f["properties"]["name"]) == key
    end)
    |> Enum.map(fn f ->
      %{
        name: f["properties"]["name"],
        place: f["properties"]["place"],
        lonlat: f["geometry"]["coordinates"]
      }
    end)
    |> Enum.sort_by(&Map.get(rank, &1.place, 9))
  end

  defp osmium!(args) do
    case System.cmd("osmium", args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {out, code} -> raise "osmium #{hd(args)} failed (#{code}): #{out}"
    end
  end

  defp to_features(
         %{
           "geometry" => %{"type" => "LineString", "coordinates" => coords},
           "properties" => props
         },
         p
       ) do
    kind = kind(props)

    names =
      @name_tags
      |> Enum.map(&props[&1])
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&String.split(&1, ";"))

    if kind && names != [] do
      xy = Enum.map(coords, &Geometry.to_xy(p, &1))

      [
        %{
          name: hd(names),
          names: names,
          keys: names |> Enum.map(&normalize/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq(),
          kind: kind,
          segments: Enum.zip(xy, tl(xy))
        }
      ]
    else
      []
    end
  end

  defp to_features(_, _), do: []

  defp kind(%{"highway" => _}), do: :street

  defp kind(%{"railway" => r})
       when r in ~w(rail abandoned disused light_rail tram razed narrow_gauge), do: :rail

  defp kind(%{"waterway" => w}) when w in ~w(river stream canal drain ditch), do: :water
  defp kind(_), do: nil

  # Name normalization -----------------------------------------------------------

  @suffixes ~w(street st avenue ave av road rd lane ln drive dr boulevard blvd place pl
               court ct way alley aly terrace ter pike turnpike highway hwy parkway pkwy
               circle cir square sq row)
  @directions ~w(north south east west n s e w)
  @ordinals %{
    "first" => "1st",
    "second" => "2nd",
    "third" => "3rd",
    "fourth" => "4th",
    "fifth" => "5th",
    "sixth" => "6th",
    "seventh" => "7th",
    "eighth" => "8th",
    "ninth" => "9th",
    "tenth" => "10th",
    "eleventh" => "11th",
    "twelfth" => "12th"
  }

  @doc """
  Reduce a street name to a comparable key: "N. Delaware St." -> "delaware",
  "Second Avenue" -> "2nd". Rail/water names keep their generic words except
  "railroad"/"creek"-style suffix variants are unified.
  """
  def normalize(name) do
    words =
      name
      |> String.downcase()
      |> String.replace(~r/['’]s\b/u, "s")
      |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
      |> String.replace(~r/\brail\s+road\b/, "railroad")
      |> String.replace(~r/\br\s*r\b/, "railroad")
      |> String.split()
      |> Enum.map(&Map.get(@ordinals, &1, &1))
      |> Enum.map(fn
        w when w in ~w(rr ry railway) -> "railroad"
        w when w in ~w(cr crk) -> "creek"
        w -> w
      end)

    strip_suffix = fn ws -> ws |> Enum.reverse() |> drop_while_in(@suffixes) |> Enum.reverse() end

    trimmed =
      words
      |> drop_while_in(@directions)
      |> then(strip_suffix)
      |> Enum.reverse()
      |> drop_while_in(@directions)
      |> Enum.reverse()

    # "West Street" is a street named West, not a direction.
    trimmed = if trimmed == [], do: strip_suffix.(words), else: trimmed
    Enum.join(if(trimmed == [], do: words, else: trimmed), " ")
  end

  defp drop_while_in(words, set), do: Enum.drop_while(words, &(&1 in set))

  @doc "Distance (m) from a projected point to the nearest feature named `key`."
  def distance_to(%__MODULE__{groups: groups}, key, xy) do
    case groups[key] do
      nil ->
        :infinity

      g ->
        g.segments
        |> Enum.map(&Geometry.point_segment_dist(xy, &1))
        |> Enum.min(fn -> :infinity end)
    end
  end

  @doc "Find the gazetteer key best matching a name read off the map, or nil."
  def match_name(%__MODULE__{groups: groups}, name) do
    key = normalize(name)

    cond do
      key == "" ->
        nil

      Map.has_key?(groups, key) ->
        key

      true ->
        groups
        |> Map.keys()
        |> Enum.map(&{&1, String.jaro_distance(&1, key)})
        |> Enum.filter(fn {k, d} ->
          d >= 0.93 and abs(String.length(k) - String.length(key)) <= 2
        end)
        |> Enum.max_by(&elem(&1, 1), fn -> nil end)
        |> case do
          nil -> nil
          {k, _} -> k
        end
    end
  end

  # Intersections ----------------------------------------------------------------

  @cluster_m 25.0

  defp intersections(groups, projection) do
    gs = groups |> Map.values() |> Enum.map(&Map.put(&1, :box, seg_bbox(&1.segments)))

    for {g1, i} <- Enum.with_index(gs),
        {g2, j} <- Enum.with_index(gs),
        i < j,
        boxes_overlap?(g1.box, g2.box),
        pt <- cluster(pair_points(g1.segments, g2.segments)) do
      {k1, k2} = Enum.min_max([g1.key, g2.key])
      %{keys: {k1, k2}, xy: pt, lonlat: Geometry.to_lonlat(projection, pt)}
    end
  end

  defp pair_points(s1, s2) do
    for a <- s1,
        abox = seg_bbox([a]),
        b <- s2,
        boxes_overlap?(abox, seg_bbox([b])),
        pt = Geometry.segment_intersection(a, b),
        pt != nil,
        do: pt
  end

  defp cluster(points) do
    Enum.reduce(points, [], fn p, acc ->
      if Enum.any?(acc, &(Geometry.dist(&1, p) < @cluster_m)), do: acc, else: [p | acc]
    end)
  end

  defp seg_bbox(segments) do
    Enum.reduce(segments, {1.0e12, 1.0e12, -1.0e12, -1.0e12}, fn {{x1, y1}, {x2, y2}},
                                                                 {a, b, c, d} ->
      {Enum.min([a, x1, x2]), Enum.min([b, y1, y2]), Enum.max([c, x1, x2]), Enum.max([d, y1, y2])}
    end)
  end

  @pad 0.5
  defp boxes_overlap?({a1, b1, c1, d1}, {a2, b2, c2, d2}) do
    a1 - @pad <= c2 and a2 - @pad <= c1 and b1 - @pad <= d2 and b2 - @pad <= d1
  end
end
