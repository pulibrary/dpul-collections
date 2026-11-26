defmodule DpulCollections.Georef.Ocr do
  @moduledoc """
  Text detection + recognition (PP-OCR models via RapidOCR/onnxruntime, run
  locally by `priv/georef/ocr.py` under `uv`). Returns rotated text boxes, which
  give each street label's position *and direction* — something a VLM's
  axis-aligned boxes can't express for diagonal streets.
  """

  @size 3000
  @version "3-v6-small-rec"

  @doc "OCR a canvas at ~#{@size}px; returns [%{text, score, quad, center, angle, height}] in canvas pixels."
  def read(canvas, fetch_image) do
    jpg = fetch_image.(DpulCollections.Georef.Manifest.image_url(canvas, "full", @size))
    [%{"width" => w, "items" => items}] = run([jpg])
    to_tokens(items, canvas.width / w)
  end

  # 2400 px tiles read at 1536 px (0.64): the pipeline's old 1800/1200 tiling
  # missed names (Millville 1903 Sheet 18's diagonal W. MAIN) that this tiling
  # detects; tiles overlap by a quarter.
  @tile 2400
  @tile_px 1536
  @stride 1800

  @doc """
  OCR a canvas in overlapping #{@tile} px tiles read at #{@tile_px} px (2/3
  resolution, against ~#{@size} px for a whole sheet in `read/2`): small or
  faint street names that the whole-sheet pass misses are read here. Tokens
  cut by an inner tile edge are dropped (the overlap holds a whole copy) and
  repeats de-duplicated. Same token shape as `read/2`, in canvas pixels.
  """
  def read_tiled(canvas, fetch_image) do
    regions =
      for x <- tile_starts(canvas.width),
          y <- tile_starts(canvas.height),
          do: {x, y, min(@tile, canvas.width - x), min(@tile, canvas.height - y)}

    jpgs =
      Enum.map(
        regions,
        &fetch_image.(DpulCollections.Georef.Manifest.image_url(canvas, &1, @tile_px))
      )

    regions
    |> Enum.zip(run(jpgs))
    |> Enum.flat_map(fn {{x0, y0, w, _} = region, %{"width" => iw, "items" => items}} ->
      items
      |> to_tokens(w / iw)
      |> Enum.map(&offset(&1, {x0, y0}))
      |> Enum.reject(&cut_by_tile_edge?(&1, region, canvas))
    end)
    |> Enum.reduce([], fn t, acc ->
      if Enum.any?(acc, &(&1.text == t.text and dist(&1.center, t.center) < 40)),
        do: acc,
        else: [t | acc]
    end)
    |> Enum.reverse()
  end

  defp tile_starts(n) do
    starts = Enum.to_list(0..max(n - @tile, 0)//@stride)
    if List.last(starts) + @tile < n, do: starts ++ [n - @tile], else: starts
  end

  defp offset(t, {dx, dy}) do
    move = fn {x, y} -> {x + dx, y + dy} end
    %{t | quad: Enum.map(t.quad, move), center: move.(t.center)}
  end

  defp cut_by_tile_edge?(%{quad: quad}, {x0, y0, w, h}, canvas) do
    {xs, ys} = Enum.unzip(quad)

    (x0 > 0 and Enum.min(xs) < x0 + 5) or (y0 > 0 and Enum.min(ys) < y0 + 5) or
      (x0 + w < canvas.width and Enum.max(xs) > x0 + w - 5) or
      (y0 + h < canvas.height and Enum.max(ys) > y0 + h - 5)
  end

  defp dist({a, b}, {c, d}), do: :math.sqrt((a - c) ** 2 + (b - d) ** 2)

  @doc """
  OCR several images (JPEG bytes, e.g. full-resolution crops) in one helper
  run; returns one token list per image, in that image's pixels.
  """
  def read_images(jpgs), do: jpgs |> run() |> Enum.map(&to_tokens(&1["items"], 1.0))

  # One JSON result per image, cached by content; the uncached ones go through
  # one ocr.py process (model loading dominates for small crops).
  defp run(jpgs) do
    dir = Path.expand("~/.cache/dpul_georef/ocr")
    File.mkdir_p!(dir)
    # bump @version when ocr.py changes so cached results are recomputed
    keyed =
      Enum.map(jpgs, fn jpg ->
        key = :crypto.hash(:md5, [jpg, @version]) |> Base.encode16() |> binary_part(0, 16)
        {key, jpg, Path.join(dir, key <> ".json")}
      end)

    todo = keyed |> Enum.reject(fn {_, _, cache} -> File.exists?(cache) end) |> Enum.uniq()

    if todo != [] do
      imgs =
        Enum.map(todo, fn {key, jpg, _} ->
          # unique per run: two runs OCRing the same image must not delete
          # each other's input
          img = Path.join(dir, "#{key}.#{System.unique_integer([:positive])}.jpg")
          File.write!(img, jpg)
          img
        end)

      script = Application.app_dir(:dpul_collections, "priv/georef/ocr.py")

      try do
        {out, 0} =
          System.cmd(
            "uv",
            ~w(run -q --with rapidocr --with onnxruntime --with pillow python -I) ++
              [script | imgs],
            stderr_to_stdout: false
          )

        for line <- String.split(out, "\n", trim: true),
            String.starts_with?(line, "{"),
            %{"image" => img} = Jason.decode!(line),
            key = img |> Path.basename() |> String.split(".") |> hd(),
            tmp = Path.join(dir, "#{key}.#{System.unique_integer([:positive])}.tmp"),
            :ok = File.write!(tmp, line),
            do: File.rename!(tmp, Path.join(dir, key <> ".json"))
      after
        Enum.each(imgs, &File.rm/1)
      end
    end

    Enum.map(keyed, fn {_, _, cache} -> cache |> File.read!() |> Jason.decode!() end)
  end

  defp to_tokens(items, s) do
    Enum.map(items, fn %{"text" => text, "score" => score, "quad" => quad} ->
      pts = Enum.map(quad, fn [x, y] -> {x * s, y * s} end)

      %{
        text: text,
        score: score,
        quad: pts,
        center: centroid(pts),
        angle: angle(pts),
        height: height(pts)
      }
    end)
  end

  defp centroid(pts) do
    {xs, ys} = Enum.unzip(pts)
    {Enum.sum(xs) / length(xs), Enum.sum(ys) / length(ys)}
  end

  # letter height: the quad's short side
  defp height([a, b, _, d]), do: min(dist(a, d), dist(a, b))
  defp height(_), do: 0.0

  # direction of the text baseline (radians, image space), from the quad's long side
  defp angle([{x0, y0}, {x1, y1}, {x2, y2} | _]) do
    {ax, ay} = {x1 - x0, y1 - y0}
    {bx, by} = {x2 - x1, y2 - y1}
    if ax * ax + ay * ay >= bx * bx + by * by, do: :math.atan2(ay, ax), else: :math.atan2(by, bx)
  end
end
