defmodule DpulCollections.Georef.GeometryTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef.Geometry

  test "the local projection is metres from the bbox centre and round-trips" do
    p = Geometry.projection({-75.04, 40.0, -75.02, 40.02})
    assert_in_delta p.lon0, -75.03, 1.0e-12
    assert_in_delta p.lat0, 40.01, 1.0e-12

    assert {x, y} = Geometry.to_xy(p, [-75.03, 40.01])
    assert_in_delta x, 0.0, 1.0e-6
    assert_in_delta y, 0.0, 1.0e-6

    # 0.001 deg of latitude is ~111 m; of longitude at 40 N, ~85 m
    {x, y} = Geometry.to_xy(p, [-75.029, 40.011])
    assert_in_delta y, 111.3, 0.1
    assert_in_delta x, 85.3, 0.1

    [lon, lat] = Geometry.to_lonlat(p, {x, y})
    assert_in_delta lon, -75.029, 1.0e-12
    assert_in_delta lat, 40.011, 1.0e-12
  end

  test "dist is euclidean" do
    assert Geometry.dist({0, 0}, {3, 4}) == 5.0
  end

  test "segment intersection includes endpoints and ignores parallel segments" do
    assert Geometry.segment_intersection({{0, 0}, {10, 0}}, {{10, 0}, {10, 5}}) == {10.0, 0.0}
    assert Geometry.segment_intersection({{0, 0}, {10, 0}}, {{0, 5}, {10, 5}}) == nil
    assert Geometry.segment_intersection({{0, 0}, {10, 0}}, {{2, 0}, {8, 0}}) == nil
  end
end
