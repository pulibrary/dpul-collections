defmodule DpulCollections.Georef.Mask do
  @moduledoc """
  Mask polygons for Georeference Annotation SvgSelectors.

  Parts of a sheet (see `DpulCollections.Georef.Parts`) are polygons in canvas
  pixels; each georeferenced part's polygon is its SvgSelector mask.
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

  @doc "Distance from a point to the polygon's outline: positive inside, negative outside."
  def signed_distance(pt, polygon) do
    d =
      polygon
      |> Enum.zip(tl(polygon) ++ [hd(polygon)])
      |> Enum.map(&DpulCollections.Georef.Geometry.point_segment_dist(pt, &1))
      |> Enum.min()

    if inside_polygon?(pt, polygon), do: d, else: -d
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
