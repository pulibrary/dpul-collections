defmodule DpulCollectionsWeb.Georeferencer.LiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  alias DpulCollections.Repo
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Atlas, Job, Queue, Review}

  setup do
    atlas =
      Repo.insert!(%Atlas{
        id: "00000000-0000-0000-0000-0000000000bb",
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

    for i <- 0..1, do: Repo.insert!(%Job{atlas_id: atlas.id, canvas_index: i})
    :ok
  end

  test "the main page shows the queue and a way to add an atlas", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/georeferencer")
    assert html =~ "Insurance maps of Testtown"
    assert html =~ "2 sheets waiting"
    assert has_element?(view, "#queue-atlas input[name=manifest]")

    assert view |> form("#queue-atlas", manifest: "not a url") |> render_submit() =~
             "Paste an IIIF manifest URL."
  end

  test "a sheet claimed by a page that goes away is put back", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/georeferencer")
    render_hook(view, "claim", %{"worker" => "tab-x"})
    assert Queue.counts() == %{"claimed" => 1, "queued" => 1}

    Process.flag(:trap_exit, true)
    ref = Process.monitor(view.pid)
    GenServer.stop(view.pid, {:shutdown, :closed})
    assert_receive {:DOWN, ^ref, _, _, _}
    assert Queue.counts() == %{"queued" => 2}
  end

  test "the results page links back to the queue", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/georeferencer/results")
    assert html =~ "Back to the queue"
  end

  @mask [[0, 0], [1000, 0], [1000, 800], [0, 800]]
  @t %{"a" => 0.04, "b" => 0.0, "tx" => 1.0, "ty" => 2.0}
  defp labels(keys), do: for(k <- keys, do: %{"key" => k, "name" => k, "px" => [10, 10]})

  # sheet 1: a weak guess; sheet 2: names but no placement
  defp finish_both do
    a = Queue.claim("tab-1", nil)
    b = Queue.claim("tab-1", nil)

    :ok =
      Queue.complete(a.id, "tab-1", nil, %{
        "parts" => [
          %{
            "part" => 1,
            "status" => "unsure",
            "mask" => @mask,
            "transform" => @t,
            "label_hits" => 3,
            "rival_hits" => 2,
            "contrast" => 0.3,
            "labels" => labels(~w(a b c d))
          }
        ]
      })

    :ok =
      Queue.complete(b.id, "tab-1", nil, %{
        "parts" => [
          %{
            "part" => 1,
            "status" => "failed",
            "mask" => @mask,
            "labels" => labels(~w(a b c)),
            "reason" => "no placement"
          }
        ]
      })
  end

  test "parts needing a person come easiest first", %{conn: _} do
    finish_both()
    assert [%{label: "Sheet 1", tier: 1}, %{label: "Sheet 2", tier: 3}] = Review.items()
    input = Collab.sheet_input(Collab.atlas("00000000-0000-0000-0000-0000000000bb"), 0)
    assert input.auto == @t and input.auto_status == "guess"
  end

  test "a guess whose printed streets don't line up ranks with the unplaced", %{conn: _} do
    a = Queue.claim("tab-1", nil)

    :ok =
      Queue.complete(a.id, "tab-1", nil, %{
        "parts" => [
          %{
            "part" => 1,
            "status" => "unsure",
            "mask" => @mask,
            "transform" => @t,
            "label_hits" => 6,
            "rival_hits" => 6,
            "contrast" => 0.04,
            "labels" => labels(~w(a b c d e f g))
          }
        ]
      })

    assert [%{tier: 3, why: why}] = Review.items()
    assert why =~ "don't line up"
    input = Collab.sheet_input(Collab.atlas("00000000-0000-0000-0000-0000000000bb"), 0)
    assert input.auto == @t and input.auto_status == "doubtful"
  end

  test "sheets fitted on top of each other come after the likely guesses", %{conn: _} do
    part = %{
      "part" => 1,
      "status" => "ok",
      "mask" => @mask,
      "transform" => @t,
      "contrast" => 0.3,
      "corridor" => [8, 2],
      "label_hits" => 5,
      "labels" => labels(~w(a b c d e))
    }

    for _ <- 1..2 do
      job = Queue.claim("tab-1", nil)
      :ok = Queue.complete(job.id, "tab-1", nil, %{"parts" => [part]})
    end

    assert [
             %{label: "Sheet 1", tier: 2, why: "lands on top of another sheet", ease: e1},
             %{label: "Sheet 2", tier: 2, region: "0,0,1000,800", ease: e2}
           ] = Review.items()

    # 3000 for the tier; lines up 300 * 0.3 + 100 * 0.8; 4 * 5 hits + 6 * 5 lead + 2 * 5 names
    assert_in_delta e1, 3000 + 90 + 80 + 20 + 30 + 10, 1.0e-9
    assert e1 == e2
  end

  test "a part without names or an outline has little to go on", %{conn: _} do
    a = Queue.claim("tab-1", nil)
    :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => [%{"part" => 1, "status" => "failed"}]})

    assert [%{tier: 4, why: "no street names read (may not be a map)", region: "full"}] =
             Review.items()
  end

  test "placing one by hand saves it, shows it on the map and moves on", %{conn: conn} do
    finish_both()
    user = user_fixture()
    conn = log_in_user(conn, user)
    Queue.subscribe()
    {:ok, view, html} = live(conn, ~p"/georeferencer/review")
    assert html =~ "review-00000000-0000-0000-0000-0000000000bb-0"

    render_hook(view, "save", %{"verdict" => "placed", "method" => "adjusted", "transform" => @t})
    assert_patch(view, ~p"/georeferencer/review/00000000-0000-0000-0000-0000000000bb/1")
    assert_receive {:georef_result, %{canvas: "Sheet 1", contributor: id}} when id == user.id
    assert [%{label: "Sheet 2"}] = Review.items()
    assert [%{method: "adjusted"}] = Collab.list_for_user(user)

    render_hook(view, "save", %{"verdict" => "cannot"})
    assert Review.items() == []
    assert render(view) =~ "Nothing needs a person right now."
  end

  @atlas_id "00000000-0000-0000-0000-0000000000bb"

  describe "the results page" do
    test "lists your contributions and each atlas's downloads", %{conn: conn} do
      user = user_fixture()
      atlas = Collab.atlas(@atlas_id)

      {:ok, placed} =
        Collab.save(user, atlas, 0, %{
          "verdict" => "placed",
          "method" => "adjusted",
          "transform" => @t
        })

      {:ok, cannot} = Collab.save(user, atlas, 1, %{"verdict" => "cannot"})

      {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/georeferencer/results")
      assert html =~ "Your contributions (2)"
      assert has_element?(view, "#my-contributions td", "placed (adjusted)")
      assert has_element?(view, "#my-contributions td", "cannot")

      for c <- [placed, cannot] do
        assert has_element?(view, ~s(a[href="/georeferencer/contributions/#{c.id}"]), "JSON")
      end

      assert has_element?(
               view,
               ~s(a[href="/georeferencer/#{@atlas_id}/0"]),
               "Insurance maps of Testtown"
             )

      assert has_element?(view, ~s(a[href="/georeferencer/atlas/#{@atlas_id}/georef.json"]))
      # two parts, none placed by a browser; two volunteer results
      assert has_element?(view, "td", "2")
    end

    test "a new volunteer has none yet", %{conn: conn} do
      {:ok, _view, html} = conn |> log_in_user(user_fixture()) |> live(~p"/georeferencer/results")
      assert html =~ "None yet"
    end

    test "asks visitors to log in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/georeferencer/results")
      refute has_element?(view, "#my-contributions")
      assert render(view) =~ "to see the results credited to you"
    end
  end

  describe "the volunteer page" do
    test "the browser's jobs: recent results, claim, complete and fail", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _} = conn |> log_in_user(user) |> live(~p"/georeferencer")

      render_hook(view, "recent", %{})
      assert_reply(view, %{items: []})

      render_hook(view, "claim", %{"worker" => "tab-1"})
      assert_reply(view, %{job: %{id: job_id, canvas_index: 0}})

      part = %{
        "part" => 1,
        "status" => "ok",
        "mask" => @mask,
        "transform" => @t,
        "contrast" => 0.3
      }

      render_hook(view, "complete", %{"job_id" => job_id, "worker" => "tab-2", "result" => %{}})
      assert_reply(view, %{ok: false, error: "not_yours"})

      render_hook(view, "complete", %{
        "job_id" => job_id,
        "worker" => "tab-1",
        "result" => %{"parts" => [part]}
      })

      assert_reply(view, %{ok: true})
      assert [%{verdict: "placed", method: "auto"}] = Collab.list_for_user(user)

      render_hook(view, "recent", %{})
      assert_reply(view, %{items: [%{canvas: "Sheet 1"}]})

      render_hook(view, "claim", %{"worker" => "tab-1"})
      assert_reply(view, %{job: %{id: job_id, canvas_index: 1}})
      render_hook(view, "fail", %{"job_id" => job_id, "worker" => "tab-1", "error" => "no GPU"})
      assert_reply(view, %{ok: true})
      assert %{status: "queued", error: "no GPU"} = Repo.get!(Job, job_id)

      render_hook(view, "claim", %{"worker" => "tab-1"})
      assert_reply(view, %{job: %{canvas_index: 1}})
      render_hook(view, "claim", %{"worker" => "tab-1"})
      assert_reply(view, %{job: nil})
    end

    test "results and queue changes reach the page", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/georeferencer")
      refute render(view) =~ "a person: place them"

      finish_both()
      send(view.pid, {:georef_result, %{canvas: "Sheet 2"}})
      assert_push_event(view, "result", %{canvas: "Sheet 2"})
      assert render_async(view) =~ "2 sheets need a person"
      assert render(view) =~ "2/2 sheets"

      send(view.pid, :queue_changed)
      assert_push_event(view, "wake", %{})
    end

    test "one sheet needing a person", %{conn: conn} do
      a = Queue.claim("tab-1", nil)

      :ok =
        Queue.complete(a.id, "tab-1", nil, %{
          "parts" => [%{"part" => 1, "status" => "failed", "mask" => @mask, "labels" => []}]
        })

      {:ok, view, _html} = live(conn, ~p"/georeferencer")
      assert render_async(view) =~ "1 sheet needs a person"
    end

    test "each atlas's progress", %{conn: conn} do
      a = Queue.claim("tab-1", nil)
      :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => []})
      Queue.claim("tab-1", nil)
      Repo.insert!(%Job{atlas_id: @atlas_id, canvas_index: 0, round: 2})
      Repo.insert!(%Job{atlas_id: @atlas_id, canvas_index: 1, round: 2, status: "failed"})

      Repo.insert!(%Atlas{
        id: "empty",
        manifest: "https://figgy.example/empty",
        label: "Insurance maps of Nowhere",
        bbox: [-74.7, 40.3, -74.6, 40.4]
      })

      {:ok, view, _} = live(conn, ~p"/georeferencer")
      assert render(view) =~ "1/2 sheets · 1 working · 1 waiting · 1 failed"
      assert has_element?(view, ~s(div[title="50% finished"]))
      assert has_element?(view, ~s(td[title="Insurance maps of Nowhere"]))
      assert has_element?(view, ~s(div[title="0% finished"]))
    end

    test "nothing queued yet", %{conn: conn} do
      Repo.delete_all(Job)
      Repo.delete_all(Atlas)
      {:ok, _view, html} = live(conn, ~p"/georeferencer")
      assert html =~ "Nothing queued yet"
    end

    test "adding an atlas from its manifest", %{conn: conn} do
      url = "https://example.org/iiif/palmyra/manifest"
      Req.Test.stub(DpulCollections.Georef, &Req.Test.json(&1, palmyra_manifest(url)))
      {:ok, view, _} = live(conn, ~p"/georeferencer")

      view |> form("#queue-atlas", manifest: "  #{url} ") |> render_submit()

      assert render_async(view) =~
               "Queued Insurance maps of Palmyra, Burlington Co., New Jersey: 1 sheet."

      assert render(view) =~ "Insurance maps of Palmyra"
    end

    test "the queued message counts the sheets", %{conn: conn} do
      url = "https://example.org/iiif/palmyra/manifest"
      m = palmyra_manifest(url)
      two = %{m | "items" => m["items"] ++ [%{hd(m["items"]) | "id" => "#{url}/canvas/2"}]}
      Req.Test.stub(DpulCollections.Georef, &Req.Test.json(&1, two))
      {:ok, view, _} = live(conn, ~p"/georeferencer")
      view |> form("#queue-atlas", manifest: url) |> render_submit()
      assert render_async(view) =~ "New Jersey: 2 sheets."
    end

    test "a manifest that can't be queued", %{conn: conn} do
      Req.Test.stub(DpulCollections.Georef, &Plug.Conn.send_resp(&1, 500, "down"))
      {:ok, view, _} = live(conn, ~p"/georeferencer")

      capture_log(fn ->
        view |> form("#queue-atlas", manifest: "https://example.org/broken") |> render_submit()
        assert render_async(view) =~ "Couldn&#39;t queue that manifest"
      end)

      refute render(view) =~ "Preparing"
    end
  end

  # a IIIF manifest of a one-sheet Palmyra atlas (the OSM fixtures are a piece of Palmyra)
  defp palmyra_manifest(url) do
    %{
      "id" => url,
      "label" => %{"en" => ["Insurance maps of Palmyra, Burlington Co., New Jersey"]},
      "navPlace" => %{
        "type" => "FeatureCollection",
        "features" => [
          %{
            "geometry" => %{
              "type" => "Polygon",
              "coordinates" => [[[-75.034, 40.0], [-75.024, 40.0], [-75.024, 40.007]]]
            }
          }
        ]
      },
      "items" => [
        %{
          "id" => "#{url}/canvas/1",
          "label" => %{"en" => ["Sheet 1"]},
          "width" => 6000,
          "height" => 7000,
          "items" => [
            %{
              "items" => [
                %{
                  "body" => %{
                    "service" => [%{"id" => "https://iiif-cloud.princeton.edu/iiif/2/p1"}]
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  end

  describe "the review page" do
    test "visitors can look but must log in to save", %{conn: conn} do
      finish_both()
      {:ok, view, html} = live(conn, ~p"/georeferencer/review")
      assert html =~ "to save your placements"
      assert html =~ "Probably right: check it (1)"
      assert html =~ "Place by its street names (1)"
      render_hook(view, "save", %{"verdict" => "cannot"})
      assert_reply(view, %{ok: false, error: "Log in to save your result."})
      assert length(Review.items()) == 2
    end

    test "the cached review list follows finished jobs" do
      Application.put_env(:dpul_collections, :review_cache, true)

      on_exit(fn ->
        Application.put_env(:dpul_collections, :review_cache, false)
        :ets.delete(Review, @atlas_id)
      end)

      :ets.delete(Review, @atlas_id)
      assert Review.items() == []
      assert [{@atlas_id, _, []}] = :ets.lookup(Review, @atlas_id)
      finish_both()
      assert length(Review.items()) == 2
    end

    test "a part number that isn't one isn't found", %{conn: conn} do
      assert_raise DpulCollectionsWeb.ItemLive.NotFoundError, fn ->
        live(conn, "/georeferencer/review/#{@atlas_id}/x")
      end
    end

    test "saving onto an atlas taken out of the queue says so", %{conn: conn} do
      finish_both()
      {:ok, view, _} = conn |> log_in_user(user_fixture()) |> live(~p"/georeferencer/review")
      DpulCollections.Repo.delete_all(DpulCollections.Georef.Collab.Atlas)
      render_hook(view, "save", %{"verdict" => "cannot"})
      assert_reply(view, %{ok: false, error: "That atlas is no longer in the queue."})
    end

    test "an invalid result isn't saved", %{conn: conn} do
      finish_both()
      {:ok, view, _} = conn |> log_in_user(user_fixture()) |> live(~p"/georeferencer/review")
      render_hook(view, "save", %{"verdict" => "maybe"})
      assert_reply(view, %{ok: false, error: error})
      assert error =~ "verdict"
    end

    test "skipping goes round the list", %{conn: conn} do
      finish_both()
      {:ok, view, _} = live(conn, ~p"/georeferencer/review/#{@atlas_id}/1")

      assert has_element?(
               view,
               "#review-#{@atlas_id}-1[data-input='/georeferencer/input/#{@atlas_id}/1']"
             )

      view |> element("button", "Skip") |> render_click()
      assert_patch(view, ~p"/georeferencer/review/#{@atlas_id}/0")
      view |> element("button", "Skip") |> render_click()
      assert_patch(view, ~p"/georeferencer/review/#{@atlas_id}/1")
    end

    test "a part no longer on the list moves on to the first", %{conn: conn} do
      finish_both()
      {:ok, view, _} = live(conn, ~p"/georeferencer/review/#{@atlas_id}/5")
      view |> element("button", "Skip") |> render_click()
      assert_patch(view, ~p"/georeferencer/review/#{@atlas_id}/0")
    end

    test "saving the last one leaves nothing to move on to", %{conn: conn} do
      a = Queue.claim("tab-1", nil)

      :ok =
        Queue.complete(a.id, "tab-1", nil, %{
          "parts" => [
            %{"part" => 1, "status" => "failed", "mask" => @mask, "labels" => labels(~w(a))}
          ]
        })

      {:ok, view, html} = conn |> log_in_user(user_fixture()) |> live(~p"/georeferencer/review")
      assert html =~ "only 1 street name read"
      render_hook(view, "save", %{"verdict" => "cannot"})
      assert_reply(view, %{ok: true, url: "/georeferencer/contributions/" <> _})
      assert render(view) =~ "Nothing needs a person right now."
      # nothing to skip to
      view |> element("button", "Skip") |> render_click()
    end

    test "new results from volunteers update the list", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/georeferencer/review")
      assert html =~ "Nothing needs a person right now."
      refute has_element?(view, "button", "Skip")
      # the queue's other news doesn't concern it
      send(view.pid, :queue_changed)
      assert render(view) =~ "Nothing needs a person right now."
      # finished sheets are announced to every open page
      finish_both()
      assert render(view) =~ "Probably right: check it (1)"
    end
  end

  describe "the sheet page" do
    test "an unknown atlas isn't found", %{conn: conn} do
      assert_raise DpulCollectionsWeb.ItemLive.NotFoundError, fn ->
        live(conn, ~p"/georeferencer/nope/0")
      end
    end

    test "a part number that isn't one, or is past the end, isn't found", %{conn: conn} do
      for i <- ["x", "-1", "2"] do
        assert_raise DpulCollectionsWeb.ItemLive.NotFoundError, fn ->
          live(conn, "/georeferencer/#{@atlas_id}/#{i}")
        end
      end
    end

    test "moves between the atlas's parts, each with its state", %{conn: conn} do
      finish_both()
      user = user_fixture()
      atlas = Collab.atlas(@atlas_id)
      {:ok, _} = Collab.save(user, atlas, 1, %{"verdict" => "cannot"})

      {:ok, view, html} = live(conn, ~p"/georeferencer/#{@atlas_id}/0")
      assert html =~ "Log in"
      assert has_element?(view, "h2", "Sheet 1")
      assert has_element?(view, ~s(span.bg-amber-500[title="not placed yet"]))
      assert has_element?(view, ~s(span.bg-stone-400[title="marked can't be placed"]))

      view |> element(~s(a[href="/georeferencer/#{@atlas_id}/1"])) |> render_click()
      assert_patch(view, ~p"/georeferencer/#{@atlas_id}/1")
      assert has_element?(view, "h2", "Sheet 2")

      assert has_element?(
               view,
               "#georeferencer-1[data-input='/georeferencer/input/#{@atlas_id}/1']"
             )
    end

    test "a person's placement and a browser's", %{conn: conn} do
      a = Queue.claim("tab-1", nil)

      part = %{
        "part" => 1,
        "status" => "ok",
        "mask" => @mask,
        "transform" => @t,
        "contrast" => 0.3
      }

      :ok = Queue.complete(a.id, "tab-1", nil, %{"parts" => [part]})

      user = user_fixture()
      {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/georeferencer/#{@atlas_id}/0")
      refute html =~ "to save results"
      assert has_element?(view, ~s(span.bg-sky-500[title="placed automatically"]))

      render_hook(view, "save", %{
        "verdict" => "placed",
        "method" => "adjusted",
        "transform" => @t
      })

      assert_reply(view, %{ok: true, id: id, url: url})
      assert url == "/georeferencer/contributions/#{id}"
      assert has_element?(view, ~s(span.bg-emerald-600[title="placed by a person"]))

      render_hook(view, "save", %{"verdict" => "maybe"})
      assert_reply(view, %{ok: false, error: error})
      assert error =~ "verdict"
    end

    test "visitors must log in to save", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/georeferencer/#{@atlas_id}/0")
      render_hook(view, "save", %{"verdict" => "cannot"})
      assert_reply(view, %{ok: false, error: "Log in to save your result."})
      assert Collab.latest_by_part(@atlas_id) == %{}
    end
  end
end
