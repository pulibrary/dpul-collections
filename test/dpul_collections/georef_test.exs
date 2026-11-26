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

  describe "Osm.match_name/2" do
    test "fuzzy-matches misreadings but never a bare street-type word" do
      osm = %Osm{groups: %{"plane" => %{}, "delaware" => %{}, "court street" => %{}}}
      assert Osm.match_name(osm, "DELAWAR ST") == "delaware"
      assert Osm.match_name(osm, "LANE") == nil
      assert Osm.match_name(osm, "Court Street") == "court street"
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

    test "maps pipeline pixels of a rescaled (non-395 dpi) scan back to image pixels" do
      [c] =
        Manifest.parse(%{
          "id" => "m",
          "items" => [
            %{
              "id" => "c",
              "width" => 6450,
              "height" => 7650,
              "items" => [
                %{
                  "items" => [
                    %{"body" => %{"service" => [%{"id" => "s", "type" => "ImageService2"}]}}
                  ]
                }
              ]
            }
          ]
        }).canvases

      assert_in_delta c.px_scale, 0.7595, 0.001
      assert {c.width, c.height} == {8493, 10073}
      assert Manifest.image_url(c, {1000, 0, 100, 100}) =~ "/759,0,76,76/"

      [a] =
        Annotation.page(%Manifest{id: "m", label: "T"}, [
          %{
            canvas: c,
            mask: [{0, 0}, {8493, 10073}],
            gcps: [%{px: {1000, 2000}, lonlat: [0.0, 0.0]}]
          }
        ])["items"]

      assert a["target"]["source"]["width"] == 6450
      assert a["target"]["selector"]["value"] =~ ~s(points="0,0 6450,7650")
      assert [%{"properties" => %{"resourceCoords" => [759, 1519]}}] = a["body"]["features"]
    end

    test "leaves ~395 dpi scans alone" do
      assert Manifest.px_scale(8470, 10080) == 1.0
    end
  end

  describe "scale_consistent?/2" do
    test "checks fitted m/px against the printed scale at scan resolution" do
      # 50 ft/in at 395 dpi = 0.0386 m/px; 0.0465 (Gloucester City's wrong fit) is 328 dpi.
      assert DpulCollections.Georef.scale_consistent?(0.0386, 50)
      refute DpulCollections.Georef.scale_consistent?(0.0465, 50)
      assert DpulCollections.Georef.scale_consistent?(0.0465, nil)
      # no printed scale: must still be a standard Sanborn scale
      refute DpulCollections.Georef.scale_consistent?(0.0187, nil)
      refute DpulCollections.Georef.scale_consistent?(0.06, nil)
    end
  end

  describe "drop_stamp_text/2" do
    test "drops labels read off a library ownership stamp" do
      tokens = [
        %{text: "PRINCETON UNIVERSITY", center: {8162, 2808}},
        %{text: "MAIN", center: {2533, 6727}}
      ]

      labels = [%{name: "DIVISION", px: {8266, 3011}}, %{name: "MAIN", px: {2533, 6727}}]
      assert [%{name: "MAIN"}] = DpulCollections.Georef.drop_stamp_text(labels, tokens)
    end
  end

  describe "drop_title_town/3" do
    test "drops the town name only where it is title lettering" do
      tokens = [%{text: "SEP.1898", center: {7000, 800}}, %{text: "N.J.", center: {7300, 1000}}]

      labels = [
        %{key: "elmer", px: {7100, 900}},
        %{key: "elmer", px: {4500, 9672}},
        %{key: "main", px: {7100, 950}}
      ]

      assert DpulCollections.Georef.drop_title_town(labels, tokens, ["elmer"]) ==
               [%{key: "elmer", px: {4500, 9672}}, %{key: "main", px: {7100, 950}}]
    end
  end

  describe "ocr_labels/2" do
    test "reads numbered streets, exactly" do
      osm = %Osm{groups: %{"3rd" => %{}, "7th" => %{}, "33rd" => %{}, "main" => %{}}}
      tok = fn text -> %{text: text, score: 0.9, center: {0, 0}, angle: 0} end

      keys =
        ["3RD", "7H", "5TH", "MAIN", "16"]
        |> Enum.map(tok)
        |> DpulCollections.Georef.ocr_labels(osm)
        |> Enum.map(& &1.key)

      assert keys == ["3rd", "7th", "main"]
    end

    test "a building-type street name must be printed at street-name size" do
      osm = %Osm{groups: %{"church" => %{}}}
      tok = fn h -> %{text: "CHURCH", score: 0.9, center: {0, 0}, angle: 0, height: h} end
      assert [] = DpulCollections.Georef.ocr_labels([tok.(86)], osm)
      assert [%{key: "church"}] = DpulCollections.Georef.ocr_labels([tok.(122)], osm)
    end
  end

  describe "Renames" do
    alias DpulCollections.Georef.Renames

    # Kings Highway runs north (x = 0); "MAIN" is printed along it on a fitted sheet.
    setup do
      osm =
        %Osm{
          groups: %{
            "kings highway" => %{
              key: "kings highway",
              kind: :street,
              segments: [{{0.0, -500.0}, {0.0, 500.0}}]
            },
            "church" => %{key: "church", kind: :street, segments: [{{-500.0, 0.0}, {500.0, 0.0}}]}
          },
          intersections: [%{keys: {"church", "kings highway"}, xy: {0.0, 0.0}, lonlat: [0, 0]}]
        }

      # identity-ish fit: 1 m per px, image up = north
      fit = %{
        status: :ok,
        transform: %{a: 1.0, b: 0.0, tx: 0.0, ty: 0.0},
        mask: [{-600, -600}, {600, -600}, {600, 600}, {-600, 600}]
      }

      vertical = :math.pi() / 2

      tok = fn text, {x, y}, a ->
        %{text: text, score: 0.9, height: 130, center: {x, y}, angle: a}
      end

      %{osm: osm, fit: fit, tok: tok, vertical: vertical}
    end

    test "learns a printed name that lies along an unmatched modern street", c do
      obs =
        Renames.observe(
          c.fit,
          [c.tok.("MAIN", {2, 100}, c.vertical), c.tok.("MAIN", {-3, -200}, c.vertical)],
          c.osm
        )

      assert obs == [{"main", "kings highway"}, {"main", "kings highway"}]
      assert Renames.table(obs) == %{"main" => "kings highway"}
    end

    test "a name printed on another street than its modern namesake votes for that street", c do
      main = %{key: "main", kind: :street, segments: [{{900.0, -500.0}, {900.0, 500.0}}]}
      osm = %{c.osm | groups: Map.put(c.osm.groups, "main", main)}

      toks = [
        c.tok.("MAIN", {2, 100}, c.vertical),
        c.tok.("MAIN", {-3, -200}, c.vertical),
        c.tok.("CHURCH", {100, 1}, 0.0)
      ]

      obs = Renames.observe(c.fit, toks, osm)
      assert Renames.table(obs) == %{"main" => "kings highway"}

      assert Osm.with_aliases(osm, %{"main" => "kings highway"}).groups["main"].segments ==
               c.osm.groups["kings highway"].segments
    end

    test "ignores text across the street, off it, or seen once", c do
      toks = [
        c.tok.("MAIN", {2, 100}, 0.0),
        c.tok.("HOTEL", {60, 100}, c.vertical),
        c.tok.("CHURCH", {100, 1}, 0.0)
      ]

      assert Renames.observe(c.fit, toks, c.osm) == [{"church", "church"}]
      assert Renames.table([{"church", "church"}, {"church", "church"}]) == %{}
      assert Renames.table([{"main", "kings highway"}]) == %{}
      assert Renames.table([{"main", "a"}, {"main", "a"}, {"main", "b"}]) == %{}
    end

    test "an alias gets the street's segments and crossings", c do
      osm = Osm.with_aliases(c.osm, %{"main" => "kings highway"})
      assert osm.groups["main"].segments == c.osm.groups["kings highway"].segments
      assert Enum.any?(osm.intersections, &(&1.keys == {"church", "main"}))
      assert Osm.match_name(osm, "MAIN") == "main"
    end
  end

  describe "printed_scale/1" do
    test "majority, then nearest the top; OCR may drop the S of SCALE" do
      toks = [
        %{text: "CALE IOOFT TO AN INCH", center: {6105, 392}},
        %{text: "SCALE 50 FT. TO AN INCH", center: {838, 8086}},
        %{text: "Scale 100 Ft. to One Inch.", center: {4684, 9505}}
      ]

      assert DpulCollections.Georef.printed_scales(toks) |> DpulCollections.Georef.printed_scale() ==
               100

      assert DpulCollections.Georef.printed_scale([
               %{ft: 50, px: {0, 900}},
               %{ft: 100, px: {0, 100}}
             ]) == 100
    end
  end

  describe "printed_scales/1" do
    test "reads feet-per-inch despite OCR digit confusions" do
      tokens =
        for text <- ["SCALE I0OFT. TO AN INCH", "Scale 150 Ft. to One Inch.", "HOLLYWOOD AV"],
            do: %{text: text, center: {1, 2}}

      assert Enum.map(DpulCollections.Georef.printed_scales(tokens), & &1.ft) == [100, 150]
    end

    test "reads a comma after Scale and Z for 2 (W. Ocean Grove 1905, Manasquan 1921)" do
      tokens =
        for text <- ["Scale, 120 Feet to One Inch.", "SCALE IZOFT TO AN INCH"],
            do: %{text: text, center: {1, 2}}

      assert Enum.map(DpulCollections.Georef.printed_scales(tokens), & &1.ft) == [120, 120]
    end
  end

  describe "Slide" do
    alias DpulCollections.Georef.Slide

    defp label(key, deg, source \\ :ocr),
      do: %{key: key, angle: deg * :math.pi() / 180, source: source, px: {0, 0}, name: key}

    test "families group parallel OCR labels of two or more streets" do
      park = label("park", 0)
      peach = label("peach", 3)
      # 178 degrees is the same direction as 0
      pear = label("pear", 178)
      church = label("church", 90)
      town = label("vineland", 1)
      vlm = label("wood", 0, :vlm)

      assert [fam] = Slide.families([park, peach, pear, church, town, vlm], ["vineland"])
      assert Enum.sort(Enum.map(fam, & &1.key)) == ["park", "peach", "pear"]
      # one street alone is no family
      assert Slide.families([park, label("park", 1), church]) == []
    end

    test "eligible only when declined without a label-line junction" do
      labels = [label("park", 0), label("peach", 0)]
      failed = %{status: :failed, located: [%{source: :vlm}], labels: labels}

      assert Slide.eligible?(failed, [])
      refute Slide.eligible?(%{failed | status: :ok}, [])
      refute Slide.eligible?(%{failed | located: [%{source: :labels}]}, [])
      refute Slide.eligible?(%{failed | labels: [label("park", 0), label("church", 90)]}, [])
    end

    test "scale class comes from the printed scale or agreeing neighbours" do
      assert Slide.scale_class(0.0387) == 50
      assert Slide.scale_class(0.0772) == 100
      assert Slide.scales_ft(200, [], 3) == {[200], 1}
      fitted = [{2, 0.0389}, {14, 0.0388}, {21, 0.0765}, {23, 0.0772}]
      assert Slide.scales_ft(nil, fitted, 22) == {[100], 1}
      assert Slide.scales_ft(nil, fitted, 5) == {[50], 1}
      # a fitted part on the same canvas counts on both sides
      assert Slide.scales_ft(nil, fitted, 14) == {[50], 1}
      # one-sided (Vineland 2 with only 19 fitted, or the last sheet): both, two reads
      assert Slide.scales_ft(nil, [{18, 0.0773}], 1) == {[50, 100], 2}
      assert Slide.scales_ft(nil, fitted, 24) == {[50, 100], 2}
      # neighbours disagree (14 at 50 ft, 21 at 100 ft): both, two reads needed
      assert Slide.scales_ft(nil, fitted, 17) == {[50, 100], 2}
      assert Slide.scales_ft(nil, [], 4) == {[50, 100], 2}
    end

    test "a read confirms, contradicts or says nothing" do
      seg = fn x -> [{{x, -500.0}, {x, 500.0}}] end

      osm = %Osm{
        groups: %{
          "4th" => %{kind: :street, segments: seg.(0.0)},
          "church" => %{kind: :street, segments: seg.(300.0)},
          "park" => %{kind: :street, segments: [{{-500.0, 0.0}, {500.0, 0.0}}]}
        }
      }

      at = {5.0, 100.0}
      assert Slide.classify_read("S. 4TH", at, osm, []) == {:match, "4th"}
      assert Slide.classify_read("CHURCH", at, osm, []) == :contra
      # family streets and the town prove nothing; junk names no street
      assert Slide.classify_read("PARK", at, osm, ["park"]) == :neutral
      assert Slide.classify_read("SHED", at, osm, []) == nil
      assert Slide.classify_read("D", at, osm, []) == nil
    end
  end

  describe "Consistency" do
    alias DpulCollections.Georef.Consistency

    # identity-ish transform: 1 m per px, so footprints equal masks
    defp part(label, x0, scale \\ 1.0) do
      %{
        canvas: %{id: label},
        part: 1,
        label: label,
        status: :ok,
        scale: scale,
        transform: %{a: 1.0, b: 0.0, tx: 0.0, ty: 0.0},
        mask: [{x0, 0.0}, {x0 + 100.0, 0.0}, {x0 + 100.0, 100.0}, {x0, 100.0}]
      }
    end

    test "overlap/2 is the shared fraction of the smaller polygon" do
      a = [{0.0, 0.0}, {100.0, 0.0}, {100.0, 100.0}, {0.0, 100.0}]
      b = [{50.0, 0.0}, {150.0, 0.0}, {150.0, 100.0}, {50.0, 100.0}]
      assert_in_delta Consistency.overlap(a, b), 0.5, 0.03
      assert Consistency.overlap(a, Enum.map(a, fn {x, y} -> {x + 200, y} end)) == 0.0
    end

    test "check/2 declines both same-scale parts that overlap by more than half" do
      out =
        Consistency.check(
          [part("Sheet 1", 0.0), part("Sheet 2", 20.0), part("Sheet 3", 300.0)],
          fn _ -> [] end
        )

      assert Enum.map(out, & &1.status) == [:failed, :failed, :ok]
    end

    test "check/2 ignores overlaps between different scales" do
      out = Consistency.check([part("Sheet 1", 0.0), part("Sheet 2", 20.0, 2.0)], fn _ -> [] end)
      assert Enum.all?(out, &(&1.status == :ok))
    end
  end

  describe "Neighbour" do
    alias DpulCollections.Georef.Neighbour

    @names %{
      "south east" => MapSet.new(["South East Boulevard"]),
      "south west" => MapSet.new(["South West Boulevard", "South West Avenue"]),
      "west" => MapSet.new(["West Avenue", "West Boulevard"]),
      "4th" => MapSet.new(["South 4th Street"]),
      "chestnut" => MapSet.new(["East Chestnut Avenue"])
    }

    test "name_keys expands direction-only names and never keys a bare direction" do
      assert Neighbour.name_keys("S. E.BOULEVARD", @names) == ["south east"]
      assert Neighbour.name_keys("S. WEST", @names) == ["south west"]
      # West Avenue or West Boulevard? A bare direction names nothing.
      assert Neighbour.name_keys("WEST", @names) == []
      assert Neighbour.name_keys("S.4TH", @names) == ["4th"]
      assert Neighbour.name_keys("5TH", @names) == []
      assert Neighbour.name_keys("CHESTNUI AVE.", @names) == ["chestnut"]
      assert Neighbour.name_keys("ELM", @names) == []
      assert Neighbour.name_keys("1925", @names) == []
    end

    test "atlas_rotation is the circular median modulo 90 degrees" do
      t = fn th -> %{a: 0.04 * :math.cos(th), b: 0.04 * :math.sin(th)} end
      half = :math.pi() / 2
      ts = [t.(0.01), t.(0.02 + half), t.(0.015 - half), t.(0.012 + :math.pi()), t.(0.6)]
      assert_in_delta Neighbour.atlas_rotation(ts), 0.015, 1.0e-3
    end

    test "sheet_refs keeps large numbers in or beside the part, not a sibling's" do
      tok = fn text, px, h -> %{text: text, center: px, height: h} end
      mask = [{0, 0}, {1000, 0}, {1000, 1000}, {0, 1000}]
      sibling = [{1000, 0}, {2000, 0}, {2000, 1000}, {1000, 1000}]

      tokens = [
        tok.("13", {500, 500}, 200),
        # just outside the part
        tok.("20 ", {-300, 500}, 250),
        # its own number, too small, too far, in the sibling, not a number
        tok.("17", {500, 600}, 200),
        tok.("14", {500, 700}, 90),
        tok.("15", {-600, 500}, 200),
        tok.("16", {1500, 500}, 200),
        tok.("A2", {500, 800}, 200)
      ]

      assert Neighbour.sheet_refs(tokens, mask, [sibling], 17) == [
               {13, {500, 500}},
               {20, {-300, 500}}
             ]

      assert Neighbour.sheet_number("Sheet 16 (part 2)") == 16
      assert Neighbour.sheet_number("Overview") == nil
    end

    test "scales_ft falls back to the class of the sheets referenced at the edges" do
      sheet = fn n, i, scale -> %{label: "Sheet #{n}", canvas: %{id: i}, scale: scale} end
      fitted = [sheet.(15, 14, 0.0388), sheet.(18, 17, 0.0782), sheet.(13, 12, 0.0386)]
      index = Map.new(0..30, &{&1, &1})
      ctx = %{fitted: fitted, index: index}
      part = %{canvas: %{id: 16}, printed_scale_ft: nil}

      # neighbours disagree (15 at 50 ft, 18 at 100 ft); a reference to 13 settles it
      assert Neighbour.scales_ft(part, ctx, [{13, {0, 0}}]) == [50]
      assert Neighbour.scales_ft(part, ctx, [{13, {0, 0}}, {18, {0, 0}}]) == [50, 100]
      assert Neighbour.scales_ft(part, ctx, []) == [50, 100]
      assert Neighbour.scales_ft(%{part | printed_scale_ft: 100}, ctx, []) == [100]
    end

    test "eligible when declined with labels on two modern streets" do
      osm = %Osm{
        groups: %{
          "chestnut" => %{kind: :street},
          "4th" => %{kind: :street},
          "vineland" => %{kind: :street},
          "pennsylvania railroad" => %{kind: :rail}
        }
      }

      l = fn key -> %{key: key, source: :ocr, angle: 0.0, px: {0, 0}} end
      r = %{status: :failed, labels: [l.("chestnut"), l.("4th")]}

      assert Neighbour.eligible?(r, osm, ["vineland"])
      refute Neighbour.eligible?(%{r | status: :ok}, osm, ["vineland"])
      refute Neighbour.eligible?(Map.put(r, :conflict, true), osm, ["vineland"])
      refute Neighbour.eligible?(%{r | labels: [l.("chestnut"), l.("chestnut")]}, osm, [])

      refute Neighbour.eligible?(%{r | labels: [l.("chestnut"), l.("vineland")]}, osm, [
               "vineland"
             ])

      refute Neighbour.eligible?(
               %{r | labels: [l.("chestnut"), l.("pennsylvania railroad")]},
               osm,
               []
             )
    end

    test "Mask.signed_distance is positive inside, negative outside" do
      sq = [{0, 0}, {100, 0}, {100, 100}, {0, 100}]
      assert_in_delta Mask.signed_distance({50, 20}, sq), 20.0, 1.0e-9
      assert_in_delta Mask.signed_distance({-30, 50}, sq), -30.0, 1.0e-9
    end
  end
end
