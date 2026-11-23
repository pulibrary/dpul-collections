defmodule DpulCollections.Georef.Ocr do
  @moduledoc """
  Text detection + recognition (PP-OCR models via RapidOCR/onnxruntime, run
  locally by `priv/georef/ocr.py` under `uv`). Returns rotated text boxes, which
  give each street label's position *and direction* — something a VLM's
  axis-aligned boxes can't express for diagonal streets.
  """

  @size 3000

  @doc "OCR a canvas at ~#{@size}px; returns [%{text, score, quad, center, angle}] in canvas pixels."
  def read(canvas, fetch_image) do
    jpg = fetch_image.(DpulCollections.Georef.Manifest.image_url(canvas, "full", @size))
    dir = Path.expand("~/.cache/dpul_georef/ocr")
    File.mkdir_p!(dir)
    key = :crypto.hash(:md5, jpg) |> Base.encode16() |> binary_part(0, 16)
    cache = Path.join(dir, key <> ".json")

    json =
      if File.exists?(cache) do
        File.read!(cache)
      else
        img = Path.join(dir, key <> ".jpg")
        File.write!(img, jpg)
        script = Application.app_dir(:dpul_collections, "priv/georef/ocr.py")

        {out, 0} =
          System.cmd(
            "uv",
            [
              "run",
              "-q",
              "--with",
              "rapidocr",
              "--with",
              "onnxruntime",
              "--with",
              "pillow",
              "python",
              "-I",
              script,
              img
            ], stderr_to_stdout: false)

        line = out |> String.split("\n", trim: true) |> List.last()
        File.write!(cache, line)
        File.rm(img)
        line
      end

    %{"width" => w, "items" => items} = Jason.decode!(json)
    s = canvas.width / w

    Enum.map(items, fn %{"text" => text, "score" => score, "quad" => quad} ->
      pts = Enum.map(quad, fn [x, y] -> {x * s, y * s} end)
      %{text: text, score: score, quad: pts, center: centroid(pts), angle: angle(pts)}
    end)
  end

  defp centroid(pts) do
    {xs, ys} = Enum.unzip(pts)
    {Enum.sum(xs) / length(xs), Enum.sum(ys) / length(ys)}
  end

  # direction of the text baseline (radians, image space), from the quad's long side
  defp angle([{x0, y0}, {x1, y1}, {x2, y2} | _]) do
    {ax, ay} = {x1 - x0, y1 - y0}
    {bx, by} = {x2 - x1, y2 - y1}
    if ax * ax + ay * ay >= bx * bx + by * by, do: :math.atan2(ay, ax), else: :math.atan2(by, bx)
  end
end
