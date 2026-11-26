defmodule DpulCollections.Georef.Py do
  @moduledoc """
  Runs a `priv/georef` Python helper that takes the canvas image and the
  OSM street geometry (slide.py, neighbour.py) under `uv`: JSON input in a
  temp file, JSON result on the last line of stdout.
  """

  @deps ~w(numpy opencv-python-headless scipy)

  @doc """
  Run `script` with `input` plus `image` (the jpg written to a temp file),
  `streets` (named street segments by key, without `exclude_keys`), `osm`
  (the extract path, for unnamed streets and railways) and `projection`.
  """
  def run(script, input, jpg, osm, exclude_keys, extra_deps \\ []) do
    dir = Path.expand("~/.cache/dpul_georef/py")
    File.mkdir_p!(dir)
    tmp = Path.join(dir, "#{System.unique_integer([:positive])}")
    File.write!(tmp <> ".jpg", jpg)

    streets =
      for {key, %{kind: :street, segments: segs}} <- osm.groups,
          key not in exclude_keys,
          into: %{},
          do: {key, Enum.map(segs, fn {{a, b}, {c, d}} -> [a, b, c, d] end)}

    input =
      Map.merge(input, %{
        image: tmp <> ".jpg",
        streets: streets,
        osm: osm.path,
        projection: Map.take(osm.projection, [:lon0, :lat0, :kx, :ky])
      })

    File.write!(tmp <> ".json", Jason.encode!(input))
    script = Application.app_dir(:dpul_collections, "priv/georef/#{script}")
    withs = Enum.flat_map(@deps ++ extra_deps, &["--with", &1])

    try do
      {out, 0} =
        System.cmd("uv", ["run", "-q" | withs] ++ ["python", "-I", script, tmp <> ".json"])

      out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
    after
      File.rm(tmp <> ".jpg")
      File.rm(tmp <> ".json")
    end
  end
end
