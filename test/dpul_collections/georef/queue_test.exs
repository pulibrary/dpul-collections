defmodule DpulCollections.Georef.QueueTest do
  use DpulCollections.DataCase
  import Ecto.Query
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Repo
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Atlas, Job, Queue}

  setup do
    atlas =
      Repo.insert!(%Atlas{
        id: "00000000-0000-0000-0000-0000000000aa",
        manifest:
          "https://figgy.example/concern/scanned_maps/00000000-0000-0000-0000-0000000000aa/manifest",
        label: "Insurance maps of Testtown",
        bbox: [-74.7, 40.3, -74.6, 40.4],
        exclude_keys: ["testtown"],
        canvases:
          for i <- 1..2 do
            %{
              "id" => "https://figgy.example/canvas/#{i}",
              "label" => "Sheet #{i}",
              "service" => "https://iiif-cloud.princeton.edu/iiif/2/s#{i}",
              "width" => 1000,
              "height" => 800
            }
          end
      })

    for i <- 0..1, do: Repo.insert!(%Job{atlas_id: atlas.id, canvas_index: i})
    %{atlas: atlas}
  end

  @part %{
    "part" => 1,
    "status" => "ok",
    "mask" => [[0, 0], [1000, 0], [1000, 800], [0, 800]],
    "transform" => %{"a" => 0.04, "b" => 0.0, "tx" => 1.0, "ty" => 2.0},
    "label_hits" => 6,
    "contrast" => 0.3
  }

  test "jobs are handed out once, oldest first, with what the browser needs" do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-2", nil)
    assert a.canvas_index == 0 and b.canvas_index == 1

    assert a.town =~
             ~r{\A/georeferencer/atlas/00000000-0000-0000-0000-0000000000aa/osm\.json\?v=\d+\z}

    assert a.exclude_keys == ["testtown"]
    assert a.canvas["service"] == "https://iiif-cloud.princeton.edu/iiif/2/s1"
    assert Queue.claim("tab-3", nil) == nil
  end

  test "a finished job credits the user with one contribution per placed part" do
    user = user_fixture()
    Queue.subscribe()
    job = Queue.claim("tab-1", user)

    assert {:error, :not_yours} = Queue.complete(job.id, "tab-2", user, %{"parts" => [@part]})

    assert :ok =
             Queue.complete(job.id, "tab-1", user, %{
               "parts" => [@part, %{@part | "part" => 2, "status" => "unsure"}]
             })

    assert Repo.get!(Job, job.id).status == "done"
    assert [c] = Collab.list_for_user(user)
    assert c.part == 1 and c.method == "auto"
    assert c.annotation["creator"]["id"] == "urn:dpul:user:#{user.id}"
    assert_receive {:georef_result, %{canvas: "Sheet 1", parts: [p1, _]}}
    assert length(p1.outline) == 4
    assert [%{canvas: "Sheet 1"}] = Queue.recent()
  end

  test "the server re-checks a browser's ok: printed streets must line up, unless a key map" do
    user = user_fixture()
    job = Queue.claim("tab-1", user)
    sideways = %{@part | "contrast" => 0.055}
    key_map = %{@part | "part" => 2, "contrast" => 0.02} |> Map.put("key_map", true)
    :ok = Queue.complete(job.id, "tab-1", user, %{"parts" => [sideways, key_map]})

    atlas = Repo.get!(Atlas, "00000000-0000-0000-0000-0000000000aa")

    assert [%{"status" => "failed", "auto_status" => "unsure"}, %{"status" => "ok"} | _] =
             Queue.parts(atlas)

    assert [%{part: 2}] = Collab.list_for_user(user)
  end

  test "a failed job goes back in the queue, then gives up after three tries" do
    for _ <- 1..3 do
      job = Queue.claim("tab-1", nil)
      assert job.canvas_index == 0
      Queue.fail(job.id, "tab-1", "boom")
    end

    assert Repo.get_by!(Job, canvas_index: 0).status == "failed"
    assert Queue.claim("tab-1", nil).canvas_index == 1
  end

  test "stale claims are handed out again" do
    job = Queue.claim("tab-1", nil)
    long_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
    Repo.get!(Job, job.id) |> Ecto.Changeset.change(claimed_at: long_ago) |> Repo.update!()
    assert Queue.claim("tab-2", nil).id == job.id
  end

  test "a closed tab's job goes straight back without using up a try" do
    job = Queue.claim("tab-1", nil)
    assert Queue.counts() == %{"claimed" => 1, "queued" => 1}
    assert Queue.release("tab-1") == 1
    again = Queue.claim("tab-2", nil)
    assert again.id == job.id
    assert Repo.get!(Job, job.id).attempts == 1
  end

  test "the queue lists atlases in order, counting quiet claims as waiting" do
    job = Queue.claim("tab-1", nil)
    assert [%{sheets: 2, counts: %{"claimed" => 1, "queued" => 1}}] = Queue.atlas_counts()
    long_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
    Repo.get!(Job, job.id) |> Ecto.Changeset.change(claimed_at: long_ago) |> Repo.update!()
    assert [%{counts: %{"queued" => 2}}] = Queue.atlas_counts()
  end

  test "a job abandoned on its last try is failed, so the atlas can finish" do
    job = Queue.claim("tab-1", nil)
    long_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    Repo.get!(Job, job.id)
    |> Ecto.Changeset.change(claimed_at: long_ago, attempts: 3)
    |> Repo.update!()

    assert Queue.claim("tab-2", nil).canvas_index == 1
    assert %{status: "failed", error: "no result after 3 tries"} = Repo.get!(Job, job.id)
  end

  test "results for jobs that don't exist are refused" do
    for id <- ["not-a-uuid", Ecto.UUID.generate()] do
      assert Queue.complete(id, "tab-1", nil, %{"parts" => []}) == {:error, :not_yours}
      assert Queue.fail(id, "tab-1", "boom") == :ok
    end
  end

  test "atlas ids come from Figgy manifests" do
    assert Queue.atlas_id(
             "https://figgy.princeton.edu/concern/scanned_maps/5094c67a-ff09-4257-8cea-9399b28e8b9a/manifest"
           ) ==
             "5094c67a-ff09-4257-8cea-9399b28e8b9a"

    assert "m-" <> _ = Queue.atlas_id("https://example.org/iiif/manifest.json")
  end

  test "renames learned from the fitted sheets send the unplaced canvases round again" do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)
    votes = [["main", "kings highway"], ["main", "kings highway"]]
    :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => [@part], "votes" => votes})
    assert Queue.claim("tab-1", nil) == nil

    :ok =
      Queue.complete(b.id, "tab-1", nil, %{
        "parts" => [%{@part | "status" => "unsure"}],
        "votes" => []
      })

    again = Queue.claim("tab-1", nil)
    assert again.canvas_index == 1 and again.round == 2
    assert again.renames == %{"main" => "kings highway"}

    # round 2 counts only when it places more parts
    elsewhere = put_in(@part, ["transform", "tx"], 500.0)
    :ok = Queue.complete(again.id, "tab-1", nil, %{"parts" => [elsewhere], "votes" => []})
    atlas = Repo.get!(Atlas, "00000000-0000-0000-0000-0000000000aa")
    assert Enum.map(Queue.parts(atlas), & &1["status"]) == ["ok", "ok"]
  end

  test "two same-scale sheets fitted on top of each other are both declined" do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)
    :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => [@part]})
    :ok = Queue.complete(b.id, "tab-1", nil, %{"parts" => [@part]})
    atlas = Repo.get!(Atlas, "00000000-0000-0000-0000-0000000000aa")

    assert Enum.map(Queue.parts(atlas), &{&1["status"], &1["conflict"]}) == [
             {"failed", true},
             {"failed", true}
           ]
  end

  # a IIIF manifest of a Palmyra atlas (the OSM fixtures are a piece of Palmyra)
  def palmyra_manifest(url) do
    %{
      "id" => url,
      "type" => "Manifest",
      "label" => %{"en" => ["Insurance maps of Palmyra, Burlington Co., New Jersey"]},
      "navPlace" => %{
        "type" => "FeatureCollection",
        "features" => [
          %{
            "type" => "Feature",
            "geometry" => %{
              "type" => "Polygon",
              "coordinates" => [
                [[-75.034, 40.0], [-75.024, 40.0], [-75.024, 40.007], [-75.034, 40.007]]
              ]
            }
          }
        ]
      },
      "items" =>
        for i <- 1..3 do
          %{
            "id" => "#{url}/canvas/#{i}",
            "type" => "Canvas",
            "label" => %{"en" => ["Sheet #{i}"]},
            "width" => 6000,
            "height" => 7000,
            "items" => [
              %{
                "items" => [
                  %{
                    "body" => %{
                      "service" => [%{"@id" => "https://iiif-cloud.princeton.edu/iiif/2/p#{i}"}]
                    }
                  }
                ]
              }
            ]
          }
        end
    }
  end

  test "an atlas is queued from its manifest, once per canvas" do
    url =
      "https://figgy.example/concern/scanned_maps/11111111-2222-3333-4444-555555555555/manifest"

    Req.Test.stub(DpulCollections.Georef, &Req.Test.json(&1, palmyra_manifest(url)))
    Queue.subscribe()

    atlas = Queue.enqueue(url)
    assert atlas.id == "11111111-2222-3333-4444-555555555555"
    assert atlas.label == "Insurance maps of Palmyra, Burlington Co., New Jersey"
    assert atlas.exclude_keys == ["palmyra"]
    [x0, y0, x1, y1] = atlas.bbox
    assert x0 <= -75.034 and y0 <= 40.0 and x1 >= -75.024 and y1 >= 40.007

    assert [%{"service" => "https://iiif-cloud.princeton.edu/iiif/2/p1", "width" => 6000} | _] =
             atlas.canvases

    assert_receive :queue_changed

    # again: nothing doubles up
    Queue.enqueue(url)
    jobs = Repo.all(from j in Job, where: j.atlas_id == ^atlas.id)
    assert Enum.map(jobs, & &1.canvas_index) |> Enum.sort() == [0, 1, 2]
  end

  test "a job is only failed by the worker holding it" do
    job = Queue.claim("tab-1", nil)
    assert Queue.fail(job.id, "tab-2", "not mine") == :ok
    assert %{status: "claimed", error: nil} = Repo.get!(Job, job.id)

    Queue.fail(job.id, "tab-1", String.duplicate("x", 5000))
    assert %{status: "queued", worker: nil, error: error} = Repo.get!(Job, job.id)
    assert String.length(error) == 4000
  end

  test "releasing a worker with nothing claimed changes nothing" do
    Queue.subscribe()
    assert Queue.release("tab-nobody") == 0
    refute_received :queue_changed
  end

  test "the last job giving up starts the rename round" do
    a = Queue.claim("tab-1", nil)
    votes = [["main", "kings highway"], ["main", "kings highway"]]

    :ok =
      Queue.complete(a.id, "tab-1", nil, %{
        "parts" => [%{@part | "status" => "unsure"}],
        "votes" => votes
      })

    for _ <- 1..3 do
      job = Queue.claim("tab-1", nil)
      assert job.canvas_index == 1
      Queue.fail(job.id, "tab-1", "boom")
    end

    again = Queue.claim("tab-1", nil)
    assert again.canvas_index == 0 and again.round == 2
    assert again.renames == %{"main" => "kings highway"}
  end

  test "no rename round without renames learned", %{atlas: atlas} do
    for _ <- 1..2 do
      job = Queue.claim("tab-1", nil)

      :ok =
        Queue.complete(job.id, "tab-1", nil, %{"parts" => [%{@part | "status" => "unsure"}]})
    end

    assert Queue.claim("tab-1", nil) == nil
    assert Repo.get!(Atlas, atlas.id).renames == %{}
  end

  test "a later round with nothing earlier to beat counts", %{atlas: atlas} do
    user = user_fixture()
    Repo.insert!(%Job{atlas_id: atlas.id, canvas_index: 0, round: 2, status: "queued"})
    Repo.update_all(from(j in Job, where: j.round == 1), set: [status: "failed"])
    job = Queue.claim("tab-1", user)
    assert job.round == 2
    :ok = Queue.complete(job.id, "tab-1", user, %{"parts" => [@part]})
    assert [%{part: 1}] = Collab.list_for_user(user)
  end

  test "the feed skips parts without a placement, newest first" do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)
    :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => [@part]})

    :ok =
      Queue.complete(b.id, "tab-1", nil, %{
        "parts" => [%{"part" => 1, "status" => "failed", "mask" => @part["mask"]}]
      })

    assert [%{canvas: "Sheet 2", parts: []}, %{canvas: "Sheet 1", parts: [p]}] = Queue.recent()
    assert p.status == "ok" and p.key_map == false and length(p.corners) == 3
    assert [%{canvas: "Sheet 2"}] = Queue.recent(1)
  end

  test "a key map's sheet number settles which of two overlapping sheets is right", %{
    atlas: atlas
  } do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)

    # Sheet 1's second part is the atlas's key map, drawn at 5x the scale, with a
    # big "2" printed where Sheet 2 lies on the ground
    key_map = %{
      @part
      | "part" => 2,
        "mask" => [[0, 0], [200, 0], [200, 160], [0, 160]],
        "transform" => %{"a" => 0.2, "b" => 0.0, "tx" => 1.0, "ty" => 2.0},
        "contrast" => 0.0
    }

    token = fn text, [x0, y0, x1, y1] ->
      %{"text" => text, "score" => 0.95, "quad" => [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]}
    end

    tokens = [
      token.("2", [80, 60, 120, 100]),
      token.("MAIN", [10, 10, 50, 20]),
      token.("ST", [10, 120, 50, 130])
    ]

    :ok =
      Queue.complete(a.id, "tab-1", nil, %{
        "parts" => [@part, Map.put(key_map, "key_map", true)],
        "tokens" => tokens
      })

    :ok = Queue.complete(b.id, "tab-1", nil, %{"parts" => [@part]})

    assert [
             %{"label" => "Sheet 1 (part 1)", "status" => "failed", "conflict" => true},
             %{"label" => "Sheet 1 (part 2)", "status" => "ok"},
             %{"label" => "Sheet 2", "status" => "ok"} = sheet2
           ] = Queue.parts(atlas)

    refute sheet2["conflict"]
  end

  test "a finished canvas with several parts labels each, and one with none is pending", %{
    atlas: atlas
  } do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)

    :ok =
      Queue.complete(a.id, "tab-1", nil, %{
        "parts" => [@part, %{@part | "part" => 2, "status" => "failed"}]
      })

    :ok = Queue.complete(b.id, "tab-1", nil, %{"parts" => []})

    assert [
             %{"label" => "Sheet 1 (part 1)", "status" => "ok"},
             %{"label" => "Sheet 1 (part 2)", "status" => "failed"},
             %{"label" => "Sheet 2", "status" => "pending", "labels" => []}
           ] = Queue.parts(atlas)
  end
end
