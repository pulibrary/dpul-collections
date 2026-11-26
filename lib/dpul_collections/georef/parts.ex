defmodule DpulCollections.Georef.Parts do
  @moduledoc """
  Splits a sheet into parts along heavy rules — Sanborn's convention for areas
  that are not geographically continuous (a detached property "1¼ miles north
  east of" town, a second street drawn below a divider). Each part is
  georeferenced on its own. Image processing lives in `priv/georef/parts.py`
  (OpenCV, run under `uv`).
  """

  @size 2000

  @doc "Part polygons ([{x, y}] in canvas px), largest first; falls back to the neatline."
  def split(canvas, neatline, fetch_image) do
    jpg = fetch_image.(DpulCollections.Georef.Manifest.image_url(canvas, "full", @size))
    dir = Path.expand("~/.cache/dpul_georef/parts")
    File.mkdir_p!(dir)

    # unique per call: concurrent runs on the same sheet must not delete
    # each other's input
    img =
      Path.join(dir, "#{System.unique_integer([:positive])}.jpg")

    File.write!(img, jpg)
    script = Application.app_dir(:dpul_collections, "priv/georef/parts.py")
    neat_args = Enum.map(neatline, fn {x, y} -> "#{round(x)},#{round(y)}" end)

    args =
      [
        "run",
        "-q",
        "--with",
        "opencv-python-headless",
        "--with",
        "numpy",
        "python",
        "-I",
        script,
        img
      ] ++
        [to_string(canvas.width), to_string(canvas.height)] ++ neat_args

    try do
      {out, 0} = System.cmd("uv", args)

      %{"parts" => parts} =
        out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()

      case Enum.map(parts, fn p -> Enum.map(p, fn [x, y] -> {x, y} end) end) do
        [] -> [neatline]
        polys -> polys
      end
    after
      File.rm(img)
    end
  end
end
