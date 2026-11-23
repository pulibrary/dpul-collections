defmodule DpulCollections.GeorefTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.{Annotation, Geometry, Manifest, Mask, Osm}

  describe "Geometry" do
    test "similarity fit recovers a known rotation/scale/translation (image y down)" do
      # 0.04 m/px, image up = west (north is to the image's right), offset.
      truth = fn {u, v} -> {100 + 0.04 * v, 200 + 0.04 * u} end
      px = [{0, 0}, {1000, 0}, {0, 2000}, {500, 700}]
      t = Geometry.fit_similarity(Enum.map(px, &{&1, truth.(&1)}))

      for p <- px, do: assert(Geometry.dist(Geometry.transform(t, p), truth.(p)) < 1.0e-6)
      assert_in_delta Geometry.scale(t), 0.04, 1.0e-9
      assert Geometry.dist(Geometry.invert(t, Geometry.transform(t, {12, 34})), {12, 34}) < 1.0e-6
    end

    test "ransac rejects a wrong correspondence and picks the right candidate per key" do
      truth = fn {u, v} -> {0.05 * u, -0.05 * v} end

      good =
        for {p, i} <- Enum.with_index([{0, 0}, {4000, 0}, {0, 4000}, {4000, 4000}]),
            do: %{key: i, px: p, xy: truth.(p)}

      wrong_alt = %{key: 0, px: {0, 0}, xy: {500.0, 500.0}}
      outlier = %{key: 9, px: {2000, 2000}, xy: {-900.0, 40.0}}

      {:ok, _t, inliers, residuals} = Geometry.ransac([wrong_alt, outlier | good], threshold: 5.0)
      assert Enum.sort(Enum.map(inliers, & &1.key)) == [0, 1, 2, 3]
      assert Enum.all?(residuals, &(&1 < 1.0e-6))
    end

    test "hypotheses, rotation and label-curve refinement" do
      truth = fn {u, v} -> {0.05 * u + 10, -0.05 * v + 20} end

      cands =
        for {p, i} <- Enum.with_index([{0, 0}, {4000, 0}, {0, 4000}]),
            do: %{key: i, px: p, xy: truth.(p)}

      [t | _] = Geometry.hypotheses(cands, scale_range: {0.01, 1.0})
      assert_in_delta Geometry.scale(t), 0.05, 1.0e-9
      assert_in_delta Geometry.rotation(t), 0.0, 1.0e-6
      assert length(Geometry.inliers_of(t, cands, 1.0)) == 3

      # perturbed start; a horizontal and a vertical "street" plus one fixed point pull it back
      start = %{t | tx: t.tx + 3}
      horizontal = {{2000, 1000}, [{truth.({-10_000, 1000}), truth.({10_000, 1000})}]}
      vertical = {{1000, 3000}, [{truth.({1000, -10_000}), truth.({1000, 10_000})}]}
      fixed = [{{0, 0}, truth.({0, 0})}]
      refined = Geometry.refine_with_curves(start, fixed, [horizontal, vertical], tolerance: 8.0)

      assert Geometry.dist(Geometry.transform(refined, {3000, 3000}), truth.({3000, 3000})) <
               0.1

      assert_in_delta Geometry.point_segment_dist({5, 5}, {{0, 0}, {10, 0}}), 5.0, 1.0e-9
    end

    test "segment intersection" do
      assert Geometry.segment_intersection({{0, 0}, {10, 0}}, {{5, -5}, {5, 5}}) == {5.0, 0.0}
      assert nil == Geometry.segment_intersection({{0, 0}, {10, 0}}, {{20, -5}, {20, 5}})
    end
  end

  describe "Osm.normalize/1" do
    test "drops suffixes, directionals and punctuation; unifies ordinals" do
      assert Osm.normalize("N. Delaware St.") == "delaware"
      assert Osm.normalize("South Commerce Street") == "commerce"
      assert Osm.normalize("Second Avenue") == "2nd"
      assert Osm.normalize("5TH ST.") == "5th"
      assert Osm.normalize("Mantua Creek") == "mantua creek"
      assert Osm.normalize("Penna. R. R.") == "penna railroad"
      # a bare directional street keeps its name
      assert Osm.normalize("West Street") == "west"
    end
  end

  describe "Mask.inside_polygon?/2" do
    test "handles concave polygons" do
      l_shape = [{0, 0}, {100, 0}, {100, 50}, {50, 50}, {50, 100}, {0, 100}]
      assert Mask.inside_polygon?({25, 75}, l_shape)
      assert Mask.inside_polygon?({75, 25}, l_shape)
      refute Mask.inside_polygon?({75, 75}, l_shape)
      assert Mask.area(l_shape) == 7500.0
      assert Mask.bbox(l_shape) == {0, 0, 100, 100}
    end
  end

  describe "Annotation" do
    test "builds a georeferencing annotation with SvgSelector mask" do
      manifest = %Manifest{id: "https://example.org/m", label: "Town"}

      canvas = %Manifest.Canvas{
        id: "https://example.org/m/c1",
        width: 100,
        height: 200,
        service_id: "https://example.org/iiif/c1",
        service_type: "ImageService2"
      }

      page =
        Annotation.page(manifest, [
          %{
            canvas: canvas,
            mask: [{1, 2}, {99, 2}, {99, 198}, {1, 198}],
            gcps: [
              %{px: {10.4, 20.6}, lonlat: [-75.1, 39.9], label: "A & B"},
              %{px: {1, 1}, lonlat: [-75.0, 39.8]}
            ]
          }
        ])

      [a] = page["items"]
      assert page["type"] == "AnnotationPage"
      assert a["motivation"] == "georeferencing"
      assert a["target"]["source"]["id"] == canvas.service_id
      assert [%{"id" => "https://example.org/m/c1"}] = a["target"]["source"]["partOf"]
      assert a["target"]["selector"]["value"] =~ ~s(<polygon points="1,2 99,2 99,198 1,198" />)
      [f, unlabelled] = a["body"]["features"]
      refute Map.has_key?(unlabelled["properties"], "label")
      assert f["properties"]["resourceCoords"] == [10, 21]
      assert f["geometry"]["coordinates"] == [-75.1, 39.9]
    end
  end
end
