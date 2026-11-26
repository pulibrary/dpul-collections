defmodule DpulCollections.Georef.Geometry do
  @moduledoc """
  Planar geometry for georeferencing: a local equirectangular projection
  (metres, accurate to well under a metre over a few km), segment
  intersection, a least-squares similarity fit and a RANSAC wrapper.
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

  def point_segment_dist(p, seg), do: dist(p, closest_on_segment(p, seg))

  def closest_on_segment({px, py}, {{x1, y1}, {x2, y2}}) do
    {dx, dy} = {x2 - x1, y2 - y1}
    len2 = dx * dx + dy * dy
    t = if len2 == 0, do: 0.0, else: max(0.0, min(1.0, ((px - x1) * dx + (py - y1) * dy) / len2))
    {x1 + t * dx, y1 + t * dy}
  end

  @doc """
  ICP-style refinement: `points` are fixed pixel->world pairs; each of `curves`
  ({px, segments}) is a pixel known to lie on a polyline. Each iteration pairs
  every curve pixel with its closest point on the polyline (if within
  `tolerance` m) and refits the similarity on everything.
  """
  def refine_with_curves(t, points, curves, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 8.0)

    Enum.reduce(1..Keyword.get(opts, :iterations, 50), t, fn _, t ->
      curve_pairs =
        for curve <- curves,
            {px, segments, polygons} = curve_parts(curve),
            w = transform(t, px),
            {q, inside} = target_with_flag(w, segments, polygons),
            inside or dist(q, w) <= tolerance,
            do: {px, q}

      fit_similarity(points ++ curve_pairs) || t
    end)
  end

  defp curve_parts({px, segments}), do: {px, segments, nil}
  defp curve_parts({px, segments, polygons}), do: {px, segments, polygons}

  # A label inside its named building pulls toward the footprint's centre
  # (Sanborn prints names mid-building; "anywhere inside" let Princeton 1918
  # Sheet 13 sit ~12 m off with every campus label still inside) -- for a
  # compact footprint; a long or L-shaped one only holds it inside. Outside,
  # it is pulled to the outline.
  @compact_m 50.0

  defp target_with_flag(w, segments, polygons) do
    inside = polygons != nil and Enum.any?(polygons, &point_in_polygon?(w, &1))
    {nearest_target(w, segments, polygons), inside}
  end

  defp nearest_target(w, segments, polygons) do
    case polygons && Enum.find(polygons, &point_in_polygon?(w, &1)) do
      nil -> Enum.min_by(Enum.map(segments, &closest_on_segment(w, &1)), &dist(&1, w))
      ring -> if extent(ring) <= @compact_m, do: ring_centroid(ring), else: w
    end
  end

  defp extent(ring) do
    {xs, ys} = Enum.unzip(ring)
    max(Enum.max(xs) - Enum.min(xs), Enum.max(ys) - Enum.min(ys))
  end

  @doc "Vertex centroid of a ring."
  def ring_centroid(ring) do
    n = length(ring)
    {sx, sy} = Enum.reduce(ring, {0.0, 0.0}, fn {x, y}, {a, b} -> {a + x, b + y} end)
    {sx / n, sy / n}
  end

  @doc "Ray-casting point-in-polygon test ({x, y} and a ring of {x, y})."
  def point_in_polygon?({x, y}, ring) do
    ring
    |> Enum.zip(tl(ring) ++ [hd(ring)])
    |> Enum.reduce(false, fn {{x1, y1}, {x2, y2}}, inside ->
      if y1 > y != y2 > y and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1,
        do: not inside,
        else: inside
    end)
  end

  # Similarity transform pixel -> metres ---------------------------------------
  #
  # Image y grows downward, map y grows north, so we flip v before fitting a
  # proper (non-reflecting) similarity: x = a*u - b*v' + tx, y = b*u + a*v' + ty
  # with v' = -v.

  def fit_similarity([]), do: nil

  def fit_similarity(pairs) do
    n = length(pairs)
    pts = Enum.map(pairs, fn {{u, v}, {x, y}} -> {u, -v, x, y} end)
    {mu, mv, mx, my} = mean4(pts, n)

    {sxx, sxy_cross, suu} =
      Enum.reduce(pts, {0.0, 0.0, 0.0}, fn {u, v, x, y}, {a, b, c} ->
        {du, dv, dx, dy} = {u - mu, v - mv, x - mx, y - my}
        {a + du * dx + dv * dy, b + du * dy - dv * dx, c + du * du + dv * dv}
      end)

    if suu < 1.0e-9 do
      nil
    else
      a = sxx / suu
      b = sxy_cross / suu
      %{a: a, b: b, tx: mx - (a * mu - b * mv), ty: my - (b * mu + a * mv)}
    end
  end

  defp mean4(pts, n) do
    {a, b, c, d} =
      Enum.reduce(pts, {0.0, 0.0, 0.0, 0.0}, fn {u, v, x, y}, {a, b, c, d} ->
        {a + u, b + v, c + x, d + y}
      end)

    {a / n, b / n, c / n, d / n}
  end

  def transform(%{a: a, b: b, tx: tx, ty: ty}, {u, v}) do
    v = -v
    {a * u - b * v + tx, b * u + a * v + ty}
  end

  def invert(%{a: a, b: b, tx: tx, ty: ty}, {x, y}) do
    s2 = a * a + b * b
    {dx, dy} = {x - tx, y - ty}
    u = (a * dx + b * dy) / s2
    v = (-b * dx + a * dy) / s2
    {u, -v}
  end

  @doc "Metres per pixel."
  def scale(%{a: a, b: b}), do: :math.sqrt(a * a + b * b)

  @doc "Bearing (degrees clockwise from north) of the image's up direction."
  def rotation(%{a: a, b: b}), do: :math.atan2(-b, a) / @deg

  # RANSAC ---------------------------------------------------------------------
  #
  # `candidates` are maps with :key (one observation may propose several world
  # points; at most one per key may be an inlier), :px {u, v}, :xy {x, y}.
  # Hypotheses come from every pair of candidates with different keys.

  @doc "Every similarity implied by a pair of candidates with different keys (scale-filtered)."
  def hypotheses(candidates, opts \\ []) do
    {min_scale, max_scale} = Keyword.get(opts, :scale_range, {0.005, 5.0})
    min_px_sep = Keyword.get(opts, :min_px_separation, 100)

    for {c1, i} <- Enum.with_index(candidates),
        {c2, j} <- Enum.with_index(candidates),
        i < j,
        c1.key != c2.key,
        dist(c1.px, c2.px) > min_px_sep,
        t = fit_similarity([{c1.px, c1.xy}, {c2.px, c2.xy}]),
        t != nil,
        scale(t) >= min_scale and scale(t) <= max_scale,
        do: t
  end

  @doc "Inliers (best candidate per key) of a transform."
  def inliers_of(t, candidates, threshold) do
    inliers(t, candidates, threshold) |> Enum.map(& &1.c)
  end

  def ransac(candidates, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 15.0)
    {min_scale, max_scale} = Keyword.get(opts, :scale_range, {0.005, 5.0})
    min_px_sep = Keyword.get(opts, :min_px_separation, 100)

    hypotheses =
      for {c1, i} <- Enum.with_index(candidates),
          {c2, j} <- Enum.with_index(candidates),
          i < j,
          c1.key != c2.key,
          dist(c1.px, c2.px) > min_px_sep,
          t = fit_similarity([{c1.px, c1.xy}, {c2.px, c2.xy}]),
          t != nil,
          scale(t) >= min_scale and scale(t) <= max_scale,
          do: t

    weight = Keyword.get(opts, :weight, fn _ -> 1 end)

    hypotheses
    |> Enum.map(fn t -> {t, inliers(t, candidates, threshold)} end)
    |> Enum.max_by(
      fn {_t, ins} -> {Enum.sum(Enum.map(ins, &weight.(&1.c))), -total_error(ins)} end,
      fn -> nil end
    )
    |> case do
      nil ->
        {:error, :no_hypothesis}

      {_t, ins} ->
        # refine: refit on inliers, recompute inliers, a couple of times
        refine(ins, candidates, threshold, 3)
    end
  end

  defp refine(ins, candidates, threshold, 0), do: finish(ins, candidates, threshold)

  defp refine(ins, candidates, threshold, n) do
    case fit_similarity(Enum.map(ins, &{&1.c.px, &1.c.xy})) do
      nil ->
        finish(ins, candidates, threshold)

      t ->
        new = inliers(t, candidates, threshold)

        if length(new) >= length(ins),
          do: refine(new, candidates, threshold, n - 1),
          else: finish(ins, candidates, threshold)
    end
  end

  defp finish(ins, _candidates, _threshold) do
    t = fit_similarity(Enum.map(ins, &{&1.c.px, &1.c.xy}))
    residuals = Enum.map(ins, fn %{c: c} -> dist(transform(t, c.px), c.xy) end)
    {:ok, t, Enum.map(ins, & &1.c), residuals}
  end

  # best candidate per key within threshold
  defp inliers(t, candidates, threshold) do
    candidates
    |> Enum.map(fn c -> %{c: c, err: dist(transform(t, c.px), c.xy)} end)
    |> Enum.filter(&(&1.err <= threshold))
    |> Enum.group_by(& &1.c.key)
    |> Enum.map(fn {_k, list} -> Enum.min_by(list, & &1.err) end)
  end

  defp total_error(ins), do: Enum.reduce(ins, 0.0, &(&1.err + &2))
end
