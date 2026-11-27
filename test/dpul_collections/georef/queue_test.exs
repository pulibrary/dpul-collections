defmodule DpulCollections.Georef.QueueTest do
  use DpulCollections.DataCase
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
    assert a.town == "/georeferencer/atlas/00000000-0000-0000-0000-0000000000aa/osm.json?v=2"
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
end
