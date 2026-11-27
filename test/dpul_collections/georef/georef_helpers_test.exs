defmodule DpulCollections.Georef.HelpersTest do
  use ExUnit.Case, async: true

  alias DpulCollections.Georef

  describe "settings" do
    test "read from the app config, with defaults" do
      assert Georef.cache_dir() =~ "dpul_georef_test_"
      assert Georef.config(:missing_key, :fallback) == :fallback
      assert Georef.req_options()[:plug] == {Req.Test, DpulCollections.Georef}
    end
  end

  describe "fetch_image/1" do
    test "fetches once, then serves the cached copy" do
      test_pid = self()

      url =
        "https://iiif.example.org/#{System.unique_integer([:positive])}/full/1500,/0/default.jpg"

      Req.Test.stub(DpulCollections.Georef, fn conn ->
        send(test_pid, {:fetched, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.send_resp(200, "jpeg bytes")
      end)

      assert Georef.fetch_image(url) == "jpeg bytes"
      assert_received {:fetched, "/" <> _}
      assert Georef.fetch_image(url) == "jpeg bytes"
      refute_received {:fetched, _}

      # no temp files are left next to the cached image
      assert Path.join([Georef.cache_dir(), "img", "*.tmp"]) |> Path.wildcard() == []
    end

    test "raises on an HTTP error and caches nothing" do
      url = "https://iiif.example.org/missing-#{System.unique_integer([:positive])}.jpg"
      Req.Test.stub(DpulCollections.Georef, &Plug.Conn.send_resp(&1, 404, "not found"))

      assert_raise RuntimeError, "image fetch failed for #{url}: HTTP 404", fn ->
        Georef.fetch_image(url)
      end

      assert_raise RuntimeError, ~r/HTTP 404/, fn -> Georef.fetch_image(url) end
    end
  end

  describe "town_name/1" do
    test "strips the title's prefix and qualifiers" do
      assert Georef.town_name(%{label: "Insurance maps of Palmyra, Burlington County"}) ==
               "Palmyra"

      assert Georef.town_name(%{label: "Insurance Map of Ocean Grove [New Jersey]"}) ==
               "Ocean Grove"

      assert Georef.town_name(%{label: "Bound Brook : Somerset County"}) == "Bound Brook"
      assert Georef.town_name(%{label: nil}) == ""
    end
  end

  # Palmyra fixtures: a village at (-75.0282, 40.0071) and a hamlet far north.
  describe "search_bbox/1" do
    defp manifest(bbox, label \\ "Insurance maps of Palmyra, New Jersey"),
      do: %{label: label, bbox: bbox}

    defp assert_bbox({a, b, c, d}, {ea, eb, ec, ed}) do
      for {got, want} <- [{a, ea}, {b, eb}, {c, ec}, {d, ed}],
          do: assert_in_delta(got, want, 1.0e-9)
    end

    test "a county-sized catalog box narrows to the town inside it" do
      assert_bbox(
        Georef.search_bbox(manifest({-75.3, 39.8, -74.8, 40.2})),
        {-75.0682271, 39.9770565, -74.9882271, 40.0370565}
      )
    end

    test "a small catalog box holding the town grows to at least a town box" do
      {a, b, c, d} = bbox = {-75.034, 40.0, -75.024, 40.007}
      {cx, cy} = {(a + c) / 2, (b + d) / 2}

      assert_bbox(
        Georef.search_bbox(manifest(bbox)),
        {cx - 0.04, cy - 0.03, cx + 0.04, cy + 0.03}
      )
    end

    test "with no catalog box (or one far from the town) it searches around the best place" do
      village = {-75.0682271, 39.9770565, -74.9882271, 40.0370565}
      assert_bbox(Georef.search_bbox(manifest(nil)), village)
      assert_bbox(Georef.search_bbox(manifest({-74.0, 41.0, -73.99, 41.01})), village)
    end

    test "a town OSM doesn't know falls back to the padded catalog box" do
      assert_bbox(
        Georef.search_bbox(manifest({-74.5, 40.0, -74.3, 40.2}, "Insurance maps of Atlantis")),
        {-74.54, 39.96, -74.26, 40.24}
      )
    end

    test "raises with neither a catalog box nor a known town" do
      assert_raise RuntimeError, ~s(no location for "Insurance maps of Atlantis"), fn ->
        Georef.search_bbox(manifest(nil, "Insurance maps of Atlantis"))
      end
    end
  end
end
