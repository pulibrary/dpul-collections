defmodule DpulCollections.Georef.Geometry do
  @moduledoc """
  Planar geometry for georeferencing: a local equirectangular projection
  (metres, accurate to well under a metre over a few km), segment
  intersection, and the similarity transform from canvas pixels to metres.
  """

  @earth 6_378_137.0
  @deg :math.pi() / 180

  # Projection ----------------------------------------------------------------

  def projection({min_lon, min_lat, max_lon, max_lat}) do
    lon0 = (min_lon + max_lon) / 2
    lat0 = (min_lat + max_lat) / 2
    %{lon0: lon0, lat0: lat0, ky: @earth * @deg, kx: @earth * @deg * :math.cos(lat0 * @deg)}
  end

  def to_xy(p, [lon, lat]), do: {(lon - p.lon0) * p.kx, (lat - p.lat0) * p.ky}
  def to_lonlat(p, {x, y}), do: [p.lon0 + x / p.kx, p.lat0 + y / p.ky]

  def dist({x1, y1}, {x2, y2}), do: :math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)

  # Segment intersection (inclusive of endpoints, small tolerance) -------------

  def segment_intersection({{x1, y1}, {x2, y2}}, {{x3, y3}, {x4, y4}}) do
    d = (x2 - x1) * (y4 - y3) - (y2 - y1) * (x4 - x3)

    if abs(d) < 1.0e-9 do
      nil
    else
      t = ((x3 - x1) * (y4 - y3) - (y3 - y1) * (x4 - x3)) / d
      u = ((x3 - x1) * (y2 - y1) - (y3 - y1) * (x2 - x1)) / d
      eps = 1.0e-6

      if t >= -eps and t <= 1 + eps and u >= -eps and u <= 1 + eps,
        do: {x1 + t * (x2 - x1), y1 + t * (y2 - y1)},
        else: nil
    end
  end

  # Similarity transform pixel -> metres: image y grows downward, map y grows
  # north, so v is flipped (the browser's engine.js uses the same convention).

  def transform(%{a: a, b: b, tx: tx, ty: ty}, {u, v}) do
    v = -v
    {a * u - b * v + tx, b * u + a * v + ty}
  end
end
