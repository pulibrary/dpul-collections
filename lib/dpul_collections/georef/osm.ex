defmodule DpulCollections.Georef.Osm do
  @moduledoc """
  Local OpenStreetMap gazetteer for a bounding box: named streets, railways and
  waterways, plus every point where two differently-named features meet.

  Data comes from a state `.osm.pbf` extract on disk (`Georef.cache_dir/0`),
  clipped with `osmium` (`devbox global add osmium-tool`). Nothing is fetched
  at query time.
  """

  alias DpulCollections.Georef
  alias DpulCollections.Georef.Geometry

  @name_tags ~w(name old_name alt_name official_name historic:name loc_name)

  # path: the clipped geojsonseq extract (helpers that need unnamed streets read it)
  defstruct [:bbox, :projection, :path, features: [], groups: %{}, intersections: []]

  def pbf_path,
    do: Georef.config(:osm_pbf, Path.join(Georef.cache_dir(), "new-jersey-latest.osm.pbf"))

  @doc """
  Other states' Geofabrik extracts next to the default one, as `[{state, path}]`:
  `oregon-latest.osm.pbf` is "oregon", `new-york-latest.osm.pbf` "new york".
  """
  def other_extracts do
    default = Path.expand(pbf_path())

    Path.join(Georef.cache_dir(), "*-latest.osm.pbf")
    |> Path.wildcard()
    |> Enum.reject(&(Path.expand(&1) == default))
    |> Enum.map(&{&1 |> Path.basename("-latest.osm.pbf") |> String.replace("-", " "), &1})
  end

  @doc "The extract for an atlas whose title names a state (\"…, Marion County, Oregon\"); else the default."
  def pbf_for_title(title) do
    t = " " <> normalize(to_string(title)) <> " "

    Enum.find_value(other_extracts(), pbf_path(), fn {state, path} ->
      if String.contains?(t, " " <> normalize(state) <> " "), do: path
    end)
  end

  @doc "The extract covering a bbox's centre: another state's if one does, else the default."
  def pbf_for({a, b, c, d}) do
    {x, y} = {(a + c) / 2, (b + d) / 2}

    Enum.find_value(other_extracts(), pbf_path(), fn {_, path} ->
      case header_box(path) do
        {x0, y0, x1, y1} when x >= x0 and x <= x1 and y >= y0 and y <= y1 -> path
        _ -> nil
      end
    end)
  end

  # the extract's bounding box from its header, read once per file
  defp header_box(path) do
    key = {__MODULE__, :header_box, path, File.stat!(path).mtime}

    case :persistent_term.get(key, :none) do
      :none ->
        box =
          case Regex.run(
                 ~r/\(([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)\)/,
                 osmium_out!(["fileinfo", "-g", "header.boxes", path])
               ) do
            [_ | nums] -> nums |> Enum.map(&String.to_float/1) |> List.to_tuple()
            _ -> nil
          end

        :persistent_term.put(key, box)
        box

      box ->
        box
    end
  end

  defp dir do
    dir = Path.join(Georef.cache_dir(), "osm")
    File.mkdir_p!(dir)
    dir
  end

  @doc "Load (and cache) the gazetteer for a {min_lon, min_lat, max_lon, max_lat} bbox."
  def load(bbox) do
    path = extract(bbox)
    projection = Geometry.projection(bbox)

    streets =
      path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.flat_map(&to_features(&1, projection))
      |> Enum.to_list()

    # Named buildings (campuses, churches, mills): a printed building name
    # sitting in its surviving footprint places the sheet like a street name.
    # A street of the same name wins.
    street_keys = streets |> Enum.flat_map(& &1.keys) |> MapSet.new()

    buildings =
      for f <- building_features(bbox, projection),
          keys = Enum.reject(f.keys, &(&1 in street_keys)),
          keys != [],
          do: %{f | keys: keys}

    features = streets ++ buildings

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
           segments: Enum.flat_map(fs, & &1.segments),
           polygons: for(f <- fs, f[:ring], do: f.ring) |> then(&if(&1 == [], do: nil, else: &1))
         }}
      end)

    %__MODULE__{
      bbox: bbox,
      projection: projection,
      path: path,
      features: features,
      groups: groups,
      intersections:
        groups |> Map.filter(fn {_, g} -> g.kind != :building end) |> intersections(projection)
    }
  end

  # Generic building names say nothing about which building it is.
  @generic_buildings ~w(garage barn shed house church school library office hall chapel
                        gymnasium dormitory store warehouse station building annex)

  defp building_features(bbox, p) do
    bbox
    |> extract_buildings()
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Stream.flat_map(fn
      %{
        "geometry" => %{"type" => type, "coordinates" => coords},
        "properties" => %{"name" => name}
      }
      when type in ["Polygon", "MultiPolygon"] and is_binary(name) ->
        rings = if type == "Polygon", do: [hd(coords)], else: Enum.map(coords, &hd/1)
        key = normalize(name)
        words = String.split(key)

        if key == "" or key in @generic_buildings or
             (length(words) == 1 and String.length(key) < 6) do
          []
        else
          for ring <- rings, length(ring) >= 4 do
            xy = ring |> Enum.map(&Geometry.to_xy(p, &1)) |> Enum.drop(-1)

            %{
              name: name,
              names: [name],
              keys: [key],
              kind: :building,
              segments: Enum.zip(xy, tl(xy) ++ [hd(xy)]),
              ring: xy
            }
          end
        end

      _ ->
        []
    end)
    |> Enum.to_list()
  end

  defp extract_buildings({a, b, c, d} = bbox) do
    dir = dir()

    key =
      :crypto.hash(:md5, :erlang.term_to_binary({:buildings, bbox}))
      |> Base.encode16()
      |> binary_part(0, 12)

    out = Path.join(dir, "B#{key}.geojsonseq")

    unless File.exists?(out) do
      tmp = Path.join(dir, "B#{key}-#{System.unique_integer([:positive])}")

      bb = Enum.join([a, b, c, d], ",")

      osmium!([
        "extract",
        "-b",
        bb,
        pbf_for(bbox),
        "-o",
        tmp <> "-clip.osm.pbf",
        "--overwrite",
        "-s",
        "smart"
      ])

      osmium!([
        "tags-filter",
        tmp <> "-clip.osm.pbf",
        "nwr/building",
        "-o",
        tmp <> "-filt.osm.pbf",
        "--overwrite"
      ])

      osmium!([
        "export",
        tmp <> "-filt.osm.pbf",
        "-f",
        "geojsonseq",
        "-x",
        "print_record_separator=false",
        "--geometry-types=polygon",
        "-o",
        tmp <> ".geojsonseq",
        "--overwrite"
      ])

      File.rename!(tmp <> ".geojsonseq", out)
      File.rm(tmp <> "-clip.osm.pbf")
      File.rm(tmp <> "-filt.osm.pbf")
    end

    out
  end

  defp extract({a, b, c, d} = bbox) do
    dir = dir()

    key =
      :crypto.hash(:md5, :erlang.term_to_binary(bbox)) |> Base.encode16() |> binary_part(0, 12)

    out = Path.join(dir, "#{key}.geojsonseq")

    unless File.exists?(out) do
      # Temp files are per-process and the result is renamed into place, so
      # concurrent runs needing the same extract don't clobber each other.
      tmp = "#{key}-#{System.pid()}-#{System.unique_integer([:positive])}"
      filt = Path.join(dir, "#{tmp}-filt.osm.pbf")

      clip = Path.join(dir, "#{tmp}-clip.osm.pbf")
      bb = Enum.join([a, b, c, d], ",")

      osmium!([
        "extract",
        "-b",
        bb,
        pbf_for(bbox),
        "-o",
        clip,
        "--overwrite",
        "-s",
        "complete_ways"
      ])

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
        Path.join(dir, "#{tmp}.geojsonseq"),
        "--overwrite"
      ])

      File.rename!(Path.join(dir, "#{tmp}.geojsonseq"), out)
      File.rm(clip)
      File.rm(filt)
    end

    out
  end

  @doc """
  Look up populated places by name in the local extract. Returns
  `[%{name, place, lonlat}]`, best (largest place type) first.
  """
  def find_place(name, pbf \\ pbf_path()) do
    dir = dir()
    # the default extract keeps its old file name
    suffix = if pbf == pbf_path(), do: "", else: "-" <> Path.basename(pbf, "-latest.osm.pbf")
    out = Path.join(dir, "places#{suffix}.geojsonseq")

    unless File.exists?(out) do
      filt = Path.join(dir, "places#{suffix}.osm.pbf")

      osmium!([
        "tags-filter",
        pbf,
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
    osmium_out!(args)
    :ok
  end

  defp osmium_out!(args) do
    case System.cmd(Georef.config(:osmium, "osmium"), args, stderr_to_stdout: true) do
      {out, 0} -> out
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
  # with the quadrants some cities add to every street ("Court Street Northeast", Salem, Oregon)
  @directions ~w(north south east west n s e w northeast northwest southeast southwest ne nw se sw)
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

    # a leading "the" is filler: "The Terrace" is Terrace, and a bare "THE" read
    # off a sheet names nothing
    words = drop_while_in(words, ~w(the))

    drop_trailing = fn ws ->
      ws |> Enum.reverse() |> drop_while_in(@directions) |> Enum.reverse()
    end

    # trailing directions go before the suffix too: "Court Street Northeast"
    trimmed =
      words
      |> drop_while_in(@directions)
      |> then(drop_trailing)
      |> then(strip_suffix)
      |> then(drop_trailing)

    # "West Street" is a street named West, not a direction; "Court Street" is named Court
    trimmed = if trimmed == [], do: strip_suffix.(drop_trailing.(words)), else: trimmed
    trimmed = if trimmed == [], do: Enum.take(drop_trailing.(words), 1), else: trimmed
    Enum.join(if(trimmed == [], do: words, else: trimmed), " ")
  end

  defp drop_while_in(words, set), do: Enum.drop_while(words, &(&1 in set))

  @doc """
  Add alias keys (%{alias => existing key}): each alias gets the existing
  street's segments and its intersections, so labels reading the alias match
  that street. Used for street renames learned from an atlas.
  """
  def with_aliases(%__MODULE__{} = osm, aliases) do
    aliases = Map.filter(aliases, fn {a, k} -> a != k and Map.has_key?(osm.groups, k) end)
    # an alias replacing an existing name drops that name's crossings
    replaced = MapSet.new(Map.keys(aliases))

    base =
      Enum.reject(osm.intersections, fn %{keys: {k1, k2}} ->
        k1 in replaced or k2 in replaced
      end)

    groups =
      Enum.reduce(aliases, osm.groups, fn {a, k}, gs ->
        Map.put(gs, a, %{gs[k] | key: a})
      end)

    extra =
      for {a, k} <- aliases,
          i <- base,
          {k1, k2} = i.keys,
          k in [k1, k2],
          other = if(k1 == k, do: k2, else: k1),
          other != a,
          do: %{i | keys: Enum.min_max([a, other])}

    %{osm | groups: groups, intersections: base ++ extra}
  end

  # Intersections ----------------------------------------------------------------

  @cluster_m 25.0

  # Spatial hash of every street segment: only segments sharing a grid cell
  # are tested, so this stays near-linear on a whole-city extract (the old
  # all-pairs-of-streets loop took ~1 h on Camden's 55 MB extract).
  @cell_m 200.0

  defp intersections(groups, projection) do
    groups
    |> Enum.flat_map(fn {key, g} -> Enum.map(g.segments, &{key, &1}) end)
    |> Enum.reduce(%{}, fn {_, seg} = item, grid ->
      Enum.reduce(
        cells(seg_bbox([seg])),
        grid,
        &Map.update(&2, &1, [item], fn l -> [item | l] end)
      )
    end)
    |> Enum.flat_map(fn {cell, items} -> cell_crossings(cell, List.to_tuple(items)) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {keys, pts} ->
      for pt <- cluster(Enum.sort(pts)),
          do: %{keys: keys, xy: pt, lonlat: Geometry.to_lonlat(projection, pt)}
    end)
  end

  # A crossing is reported only by the cell that contains it, so segments
  # spanning several cells don't produce duplicates.
  defp cell_crossings(cell, items) do
    n = tuple_size(items)

    for i <- 0..(n - 2)//1,
        j <- (i + 1)..(n - 1)//1,
        {k1, a} = elem(items, i),
        {k2, b} = elem(items, j),
        k1 != k2,
        pt = Geometry.segment_intersection(a, b),
        pt != nil,
        cell_of(pt) == cell,
        do: {Enum.min_max([k1, k2]), pt}
  end

  defp cells({a, b, c, d}) do
    {i0, j0} = cell_of({a, b})
    {i1, j1} = cell_of({c, d})
    for i <- i0..i1, j <- j0..j1, do: {i, j}
  end

  defp cell_of({x, y}), do: {floor(x / @cell_m), floor(y / @cell_m)}

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
end
