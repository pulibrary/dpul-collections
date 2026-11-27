defmodule DpulCollections.Georef.Mask do
  @moduledoc """
  Polygon helpers for map parts: a sheet's parts (found in the browser,
  assets/js/georeferencer/sheetgeom.js) are polygons in canvas pixels, and
  each placed part's polygon is its annotation's SvgSelector mask.
  """

  @doc "Even-odd point-in-polygon test."
  def inside_polygon?({x, y}, polygon) do
    polygon
    |> Enum.zip(tl(polygon) ++ [hd(polygon)])
    |> Enum.reduce(false, fn {{x1, y1}, {x2, y2}}, inside ->
      if y1 > y != y2 > y and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1,
        do: not inside,
        else: inside
    end)
  end

  def bbox(points) do
    {xs, ys} = Enum.unzip(points)
    {Enum.min(xs), Enum.min(ys), Enum.max(xs), Enum.max(ys)}
  end

  def area(points) do
    points
    |> Enum.zip(tl(points) ++ [hd(points)])
    |> Enum.reduce(0, fn {{x1, y1}, {x2, y2}}, acc -> acc + x1 * y2 - x2 * y1 end)
    |> abs()
    |> Kernel./(2)
  end
end
