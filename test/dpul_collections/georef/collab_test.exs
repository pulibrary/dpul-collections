defmodule DpulCollections.Georef.CollabTest do
  use DpulCollections.DataCase
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Repo
  alias DpulCollections.Georef.{Collab, Geometry}
  alias DpulCollections.Georef.Collab.{Atlas, Contribution, Job}

  @atlas %{
    "id" => "00000000-0000-0000-0000-000000000001",
    "label" => "Insurance maps of Testtown",
    "manifest" => "https://figgy.example/manifest",
    "bbox" => [-74.7, 40.3, -74.6, 40.4],
    "canvases" => [
      %{
        "id" => "https://figgy.example/canvas/1",
        "label" => "Sheet 1",
        "part" => 1,
        "status" => "ok",
        "service" => "https://iiif-cloud.princeton.edu/iiif/2/abc",
        "width" => 1000,
        "height" => 800,
        "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
        "labels" => [],
        "transform" => %{"a" => 0.04, "b" => 0.0, "tx" => 10.0, "ty" => 20.0}
      },
      %{
        "id" => "https://figgy.example/canvas/2",
        "label" => "Sheet 2",
        "part" => 1,
        "status" => "failed",
        "service" => "https://iiif-cloud.princeton.edu/iiif/2/def",
        "width" => 1000,
        "height" => 800,
        "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
        "labels" => [],
        "transform" => nil
      }
    ]
  }

  test "a volunteer's placement is saved with its annotation, credited, and wins in the atlas page" do
    user = user_fixture()
    t = %{"a" => 0.0, "b" => 0.04, "tx" => 5.0, "ty" => 6.0}

    {:ok, c} =
      Collab.save(user, @atlas, 1, %{
        "verdict" => "placed",
        "method" => "auto",
        "transform" => t,
        "scores" => %{"label_hits" => 5}
      })

    assert c.user_id == user.id
    assert [%{id: id}] = Collab.list_for_user(user)
    assert id == c.id

    a = c.annotation
    assert a["creator"]["id"] == "urn:dpul:user:#{user.id}"

    assert a["target"]["source"]["partOf"] |> hd() |> Map.get("id") ==
             "https://figgy.example/canvas/2"

    # control points are the outline corners carried through the transform
    [f | _] = a["body"]["features"]
    p = Collab.projection(@atlas)
    {x, y} = Geometry.transform(%{a: 0.0, b: 0.04, tx: 5.0, ty: 6.0}, {0, 0})
    [lon, lat] = Geometry.to_lonlat(p, {x, y})
    assert f["properties"]["resourceCoords"] == [0, 0]
    assert_in_delta hd(f["geometry"]["coordinates"]), lon, 1.0e-6
    assert_in_delta List.last(f["geometry"]["coordinates"]), lat, 1.0e-6

    page = Collab.atlas_page(@atlas)
    # Sheet 1 from the server prototype, Sheet 2 from the volunteer
    assert length(page["items"]) == 2
    assert Enum.at(page["items"], 1)["creator"]
  end

  test "\"can't place\" removes the server fit from the atlas page" do
    user = user_fixture()
    {:ok, _} = Collab.save(user, @atlas, 0, %{"verdict" => "cannot"})
    assert Collab.atlas_page(@atlas)["items"] == []
  end

  test "only Princeton's image server is proxied" do
    assert Collab.allowed_service?("https://iiif-cloud.princeton.edu/iiif/2/abc")
    refute Collab.allowed_service?("http://169.254.169.254/latest")
    refute Collab.allowed_service?("https://evil.example/iiif")
  end

  test "atlases are looked up by a safe id only" do
    assert Collab.atlas("../../etc/passwd") == nil
    assert Collab.atlas(nil) == nil
    assert Collab.atlas("00000000-0000-0000-0000-00000000dead") == nil
  end

  describe "a queued atlas" do
    setup do
      atlas =
        Repo.insert!(%Atlas{
          id: "00000000-0000-0000-0000-0000000000cc",
          manifest: "https://figgy.example/manifest",
          label: "Insurance maps of Testtown",
          bbox: [-74.7, 40.3, -74.6, 40.4],
          canvases:
            for i <- 1..2 do
              %{
                "id" => "c#{i}",
                "label" => "Sheet #{i}",
                "service" => "https://iiif-cloud.princeton.edu/iiif/2/s#{i}",
                "width" => 1000,
                "height" => 800
              }
            end
        })

      Repo.insert!(%Job{
        atlas_id: atlas.id,
        canvas_index: 0,
        status: "done",
        result: %{
          "parts" => [
            %{
              "part" => 1,
              "status" => "ok",
              "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
              "transform" => %{"a" => 0.04, "b" => 0.0, "tx" => 1.0, "ty" => 2.0},
              "contrast" => 0.3
            }
          ]
        }
      })

      Repo.insert!(%Job{atlas_id: atlas.id, canvas_index: 1})
      %{atlas: atlas}
    end

    test "lists with its parts and how many are placed" do
      assert [%{id: "00000000-0000-0000-0000-0000000000cc", parts: 2, placed: 1}] =
               Collab.list_atlases()

      a = Collab.atlas("00000000-0000-0000-0000-0000000000cc")
      assert a["label"] == "Insurance maps of Testtown"
      assert Enum.map(a["canvases"], & &1["status"]) == ["ok", "pending"]
    end
  end

  # sheet 1 placed by a browser; sheet 2 not placed; sheet 3 an unsure guess
  @three Map.put(
           @atlas,
           "canvases",
           Enum.map(@atlas["canvases"], &Map.put(&1, "scale_m_per_px", 0.04)) ++
             [
               %{
                 "id" => "https://figgy.example/canvas/3",
                 "label" => "Sheet 3",
                 "part" => 1,
                 "status" => "failed",
                 "service" => "https://iiif-cloud.princeton.edu/iiif/2/ghi",
                 "width" => 1000,
                 "height" => 800,
                 "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
                 "labels" => [%{"key" => "main", "name" => "Main", "px" => [1, 2], "x" => 9}],
                 "transform" => %{"a" => 0.03, "b" => 0.0, "tx" => 0.0, "ty" => 0.0},
                 "contrast" => 0.2
               }
             ]
         )

  test "a sheet's input carries its guess and its neighbours' current placements" do
    input = Collab.sheet_input(@three, 1)
    assert input.auto == nil and input.auto_status == nil
    assert input.scales == [0.04]
    assert input.osm == Collab.osm_url(@atlas)
    # only the placed sheet 1 is shown around it; the unsure guess isn't
    assert [%{transform: %{"a" => 0.04}}] = input.neighbours

    assert Collab.sheet_input(@three, 0).auto_status == "ok"

    input = Collab.sheet_input(@three, 2)
    assert input.auto_status == "guess"
    assert input.canvas.labels == [%{"key" => "main", "name" => "Main", "px" => [1, 2]}]

    # a person's word beats the browser's: sheet 3 placed by hand, sheet 1 can't be placed
    user = user_fixture()
    t = %{"a" => 0.0, "b" => 0.03, "tx" => 1.0, "ty" => 1.0}
    {:ok, _} = Collab.save(user, @three, 2, %{"verdict" => "placed", "transform" => t})
    {:ok, _} = Collab.save(user, @three, 0, %{"verdict" => "cannot"})
    assert [%{transform: ^t}] = Collab.sheet_input(@three, 1).neighbours
  end

  test "where each part stands" do
    user = user_fixture()
    [ok, failed, guess] = @three["canvases"]
    assert Collab.part_state(ok, %{}) == :auto
    assert Collab.part_state(failed, %{}) == :unplaced

    t = %{"a" => 0.0, "b" => 0.03, "tx" => 1.0, "ty" => 1.0}
    timings = %{"timings" => %{"total" => 3}}

    {:ok, _} =
      Collab.save(user, @three, 0, %{
        "verdict" => "placed",
        "method" => "auto",
        "transform" => t,
        "compute" => timings
      })

    # an automatic save on a part the server's check turned down doesn't stand
    {:ok, _} =
      Collab.save(user, @three, 2, %{
        "verdict" => "placed",
        "method" => "auto",
        "transform" => t,
        "compute" => timings
      })

    {:ok, _} = Collab.save(user, @three, 1, %{"verdict" => "cannot"})
    latest = Collab.latest_by_part(@atlas["id"])
    assert Collab.part_state(ok, latest) == :auto
    assert Collab.part_state(guess, latest) == :unplaced
    assert Collab.part_state(failed, latest) == :cannot

    {:ok, _} =
      Collab.save(user, @three, 2, %{
        "verdict" => "placed",
        "method" => "adjusted",
        "transform" => t
      })

    assert Collab.part_state(guess, Collab.latest_by_part(@atlas["id"])) == :by_person
    assert Collab.counts_by_atlas() == %{@atlas["id"] => 3}
  end

  test "a person's confirmation counts as theirs; a queue save with timings doesn't" do
    assert Collab.human?(%Contribution{verdict: "placed", method: "auto", compute: nil})
    assert Collab.human?(%Contribution{verdict: "placed", method: "adjusted"})
    refute Collab.human?(%Contribution{verdict: "placed", compute: %{"timings" => %{}}})
  end

  test "an invalid result isn't saved" do
    assert {:error, cs} = Collab.save(user_fixture(), @atlas, 0, %{"verdict" => "maybe"})
    assert cs.errors[:verdict]
  end

  test "contributions are fetched by id" do
    {:ok, c} = Collab.save(user_fixture(), @atlas, 0, %{"verdict" => "cannot"})
    assert Collab.get!(c.id).verdict == "cannot"
  end

  # a piece of Palmyra NJ (test/support/georef/fixtures)
  @palmyra %{
    "id" => "collab-test-palmyra",
    "bbox" => [-75.034, 40.0, -75.024, 40.007],
    "renames" => %{"table" => %{"high" => "market"}}
  }

  test "the town for the browser: named features with the learned renames, and the drawn lines" do
    payload = Jason.decode!(Collab.osm_payload(@palmyra))
    # fetched once per atlas
    assert Collab.osm_payload(@palmyra) == Collab.osm_payload(@palmyra)

    assert %{"kind" => "street", "segs" => [_, _, _, _ | _] = segs} = payload["groups"]["market"]
    assert payload["groups"]["high"]["segs"] == segs
    assert Enum.all?(segs, &is_float/1)

    assert [[a, b, x, y] | _] = payload["crossings"]
    assert is_binary(a) and is_binary(b) and is_float(x) and is_float(y)
    assert Enum.any?(payload["crossings"], &("high" in &1))

    # streets (1) and the railway (2), but not footways or service roads
    kinds = payload["lines"] |> Enum.map(&hd/1) |> Enum.frequencies()
    assert kinds[2] == 1
    assert kinds[1] == 52
    assert Map.keys(kinds) |> Enum.sort() == [1, 2]
  end

  test "learning renames refreshes the town, and its URL so browsers refetch" do
    before = %{@palmyra | "id" => "collab-test-renamed", "renames" => %{}}
    after_round = %{before | "renames" => %{"table" => %{"high" => "market"}}}

    refute Map.has_key?(Jason.decode!(Collab.osm_payload(before))["groups"], "high")
    assert Map.has_key?(Jason.decode!(Collab.osm_payload(after_round))["groups"], "high")
    refute Collab.osm_url(before) == Collab.osm_url(after_round)
  end

  test "the town without renames" do
    payload = Collab.osm_payload(%{@palmyra | "id" => "collab-test-plain", "renames" => %{}})
    groups = Jason.decode!(payload)["groups"]
    assert Map.has_key?(groups, "market")
    refute Map.has_key?(groups, "high")
  end

  test "an OCR model directory under the cache" do
    assert Collab.ocr_model_dir() ==
             Path.join(DpulCollections.Georef.cache_dir(), "ocr_web")
  end
end
