defmodule DpulCollections.Georef.Mask do
  @moduledoc """
  Polygon helpers for map parts: a sheet's parts (found in the browser,
  assets/js/georeferencer/sheetgeom.js) are polygons in canvas pixels, and
  each placed part's polygon is its annotation's SvgSelector mask.
  """

  @doc "Even-odd point-in-polygon test."
  # walks the edges without building them (hot: the atlas overlap check calls it millions of times)
  def inside_polygon?({x, y}, [first | _] = polygon), do: crossings(polygon, first, x, y, false)

  defp crossings([p1], first, x, y, inside), do: cross(p1, first, x, y, inside)

  defp crossings([p1 | [p2 | _] = rest], first, x, y, inside),
    do: crossings(rest, first, x, y, cross(p1, p2, x, y, inside))

  defp cross({x1, y1}, {x2, y2}, x, y, inside) do
    if y1 > y != y2 > y and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1,
      do: not inside,
      else: inside
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
