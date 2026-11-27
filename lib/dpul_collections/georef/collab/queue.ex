defmodule DpulCollections.Georef.Collab.Queue do
  @moduledoc """
  The volunteer job queue. An atlas is queued from its IIIF manifest: the
  server fetches the manifest and works out where the town is (cheap); each
  canvas becomes a job that a volunteer's browser claims, georeferences
  (assets/js/georeferencer/pipeline.js) and completes. A claim that goes quiet
  for #{10} minutes (tab closed) is handed out again.
  """

  import Ecto.Query
  alias DpulCollections.Repo
  alias DpulCollections.Georef
  alias DpulCollections.Georef.{Geometry, Manifest, Osm}
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Atlas, Job}

  @stale_seconds 600
  @max_attempts 3
  @topic "georef:feed"

  def topic, do: @topic
  def subscribe, do: Phoenix.PubSub.subscribe(DpulCollections.PubSub, @topic)
  defp broadcast(msg), do: Phoenix.PubSub.broadcast(DpulCollections.PubSub, @topic, msg)

  @doc "Queue every canvas of an atlas (idempotent per atlas and canvas)."
  def enqueue(manifest_url) do
    manifest = Manifest.fetch(manifest_url)
    bbox = Georef.search_bbox(manifest)
    # prepare the town's street extract now, so the first volunteer doesn't wait on it
    Osm.load(bbox)
    id = atlas_id(manifest.id)

    atlas =
      %Atlas{id: id}
      |> Atlas.changeset(%{
        manifest: manifest.id,
        label: manifest.label,
        bbox: Tuple.to_list(bbox),
        exclude_keys: [Osm.normalize(Georef.town_name(manifest))],
        canvases:
          for c <- manifest.canvases do
            %{
              "id" => c.id,
              "label" => c.label,
              "service" => c.service_id,
              "width" => round(c.width * c.px_scale),
              "height" => round(c.height * c.px_scale)
            }
          end
      })
      |> Repo.insert!(
        on_conflict: {:replace, [:label, :bbox, :exclude_keys, :canvases, :updated_at]},
        conflict_target: :id
      )

    now = DateTime.utc_now()

    rows =
      for i <- 0..(length(atlas.canvases) - 1)//1,
          do: %{
            id: Ecto.UUID.generate(),
            atlas_id: id,
            canvas_index: i,
            status: "queued",
            attempts: 0,
            inserted_at: now,
            updated_at: now
          }

    Repo.insert_all(Job, rows,
      on_conflict: :nothing,
      conflict_target: [:atlas_id, :canvas_index, :round]
    )

    broadcast(:queue_changed)
    atlas
  end

  # Figgy manifests -> their resource id; other manifests -> a hash of the URL
  def atlas_id(manifest_id) do
    case Regex.run(~r"/concern/scanned_maps/([0-9a-f-]{36})/manifest", manifest_id) do
      [_, uuid] ->
        uuid

      _ ->
        "m-" <>
          (:crypto.hash(:md5, manifest_id) |> Base.encode16(case: :lower) |> binary_part(0, 16))
    end
  end

  def get_atlas(id), do: Repo.get(Atlas, id)

  @doc """
  Hand the oldest waiting job (or one whose claim went stale) to a worker.
  Returns the job with everything the browser needs, or nil.
  """
  def claim(worker, user) do
    stale = DateTime.add(DateTime.utc_now(), -@stale_seconds, :second)

    Repo.transaction(fn ->
      job =
        Repo.one(
          from j in Job,
            where:
              (j.status == "queued" or (j.status == "claimed" and j.claimed_at < ^stale)) and
                j.attempts < @max_attempts,
            order_by: [asc: j.round, asc: j.inserted_at, asc: j.canvas_index],
            limit: 1,
            lock: "FOR UPDATE SKIP LOCKED"
        )

      if job do
        job
        |> Ecto.Changeset.change(%{
          status: "claimed",
          claimed_at: DateTime.utc_now(),
          worker: worker,
          user_id: user && user.id,
          attempts: job.attempts + 1
        })
        |> Repo.update!()
      end
    end)
    |> case do
      {:ok, nil} ->
        nil

      {:ok, job} ->
        broadcast(:queue_changed)
        payload(job)
    end
  end

  defp payload(job) do
    atlas = Repo.get!(Atlas, job.atlas_id)

    %{
      id: job.id,
      atlas: %{id: atlas.id, label: atlas.label},
      canvas: Enum.at(atlas.canvases, job.canvas_index),
      canvas_index: job.canvas_index,
      town: "/georeferencer/atlas/#{atlas.id}/osm.json?v=2",
      exclude_keys: atlas.exclude_keys,
      round: job.round,
      renames: if(job.round > 1, do: atlas.renames || %{}, else: %{})
    }
  end

  @doc """
  Store a worker's result: the job's full result, plus a credited
  Contribution (with its IIIF annotation) for each part it placed.
  """
  def complete(job_id, worker, user, result) do
    job = Repo.get!(Job, job_id)

    if job.status == "claimed" and job.worker == worker do
      atlas = Atlas |> Repo.get!(job.atlas_id) |> Atlas.base()
      canvas = Enum.at(atlas["sheets"], job.canvas_index)
      parts = result["parts"] || []

      Repo.transaction(fn ->
        job
        |> Ecto.Changeset.change(%{
          status: "done",
          result: result,
          finished_at: DateTime.utc_now(),
          user_id: user && user.id
        })
        |> Repo.update!()

        better? = job.round == 1 or fitted(parts) > fitted(earlier_parts(job))

        for p <- parts, p["status"] == "ok", user != nil, better? do
          {:ok, _} =
            Collab.save_part(
              user,
              atlas,
              Map.merge(canvas, %{"mask" => p["mask"], "part" => p["part"]}),
              %{
                "verdict" => "placed",
                "method" => "auto",
                "transform" => p["transform"],
                "scores" =>
                  Map.take(p, ~w(label_hits rival_hits contrast corridor scale_m_per_px)),
                "compute" => Map.take(result, ~w(timings counts gpu))
              }
            )
        end
      end)

      broadcast({:georef_result, feed_item(atlas, canvas, parts, user)})
      maybe_rename_round(job.atlas_id)
      :ok
    else
      {:error, :not_yours}
    end
  end

  defp fitted(parts), do: Enum.count(parts || [], &(&1["status"] == "ok"))

  defp earlier_parts(job) do
    Repo.one(
      from j in Job,
        where:
          j.atlas_id == ^job.atlas_id and j.canvas_index == ^job.canvas_index and
            j.round < ^job.round and j.status == "done",
        order_by: [desc: j.round],
        limit: 1,
        select: j.result
    )
    |> case do
      %{"parts" => ps} -> ps
      _ -> []
    end
  end

  @doc """
  Once every round-1 job of an atlas is finished: street renames learned from
  the fitted sheets (the browsers' `votes`, `Georef.Renames` rules), and if
  there are any, the canvases with an unplaced part go round again with them.
  """
  def maybe_rename_round(atlas_id) do
    jobs = Repo.all(from j in Job, where: j.atlas_id == ^atlas_id)
    round1 = Enum.filter(jobs, &(&1.round == 1))

    if round1 != [] and Enum.all?(round1, &(&1.status in ~w(done failed))) and
         not Enum.any?(jobs, &(&1.round > 1)) do
      votes =
        for j <- round1,
            j.status == "done",
            [printed, modern] <- (j.result || %{})["votes"] || [],
            do: {printed, modern}

      table = DpulCollections.Georef.Renames.table(votes)

      again =
        for j <- round1,
            j.status == "done",
            Enum.any?((j.result || %{})["parts"] || [], &(&1["status"] != "ok")),
            do: j.canvas_index

      if table != %{} and again != [] do
        Repo.get!(Atlas, atlas_id) |> Ecto.Changeset.change(renames: table) |> Repo.update!()
        now = DateTime.utc_now()

        Repo.insert_all(
          Job,
          for(
            i <- again,
            do: %{
              id: Ecto.UUID.generate(),
              atlas_id: atlas_id,
              canvas_index: i,
              round: 2,
              status: "queued",
              attempts: 0,
              inserted_at: now,
              updated_at: now
            }
          ),
          on_conflict: :nothing,
          conflict_target: [:atlas_id, :canvas_index, :round]
        )

        broadcast(:queue_changed)
      end
    end

    :ok
  end

  def fail(job_id, worker, error) do
    job = Repo.get!(Job, job_id)

    if job.status == "claimed" and job.worker == worker do
      status = if job.attempts >= @max_attempts, do: "failed", else: "queued"

      job
      |> Ecto.Changeset.change(%{
        status: status,
        error: String.slice(error, 0, 4000),
        worker: nil
      })
      |> Repo.update!()

      if status == "failed", do: maybe_rename_round(job.atlas_id)
      broadcast(:queue_changed)
    end

    :ok
  end

  @doc "What the map shows for a finished canvas: each part's outline in lon/lat."
  def feed_item(atlas, canvas, parts, user) do
    p = Collab.projection(atlas)

    %{
      atlas: atlas["label"],
      atlas_id: atlas["id"],
      canvas: canvas["label"],
      service: canvas["service"],
      width: canvas["width"],
      height: canvas["height"],
      contributor: user && user.id,
      parts: Enum.flat_map(parts, &outline(&1, p))
    }
  end

  defp outline(%{"transform" => %{"a" => a, "b" => b, "tx" => tx, "ty" => ty}} = part, p) do
    t = %{a: a, b: b, tx: tx, ty: ty}

    [
      %{
        status: part["status"],
        part: part["part"],
        key_map: part["key_map"] == true,
        mask: part["mask"],
        outline:
          for([u, v] <- part["mask"], do: Geometry.to_lonlat(p, Geometry.transform(t, {u, v}))),
        # canvas (0,0), (1000,0), (0,1000) on the map: the browser's image overlay is affine
        corners:
          for(
            px <- [{0, 0}, {1000, 0}, {0, 1000}],
            do: Geometry.to_lonlat(p, Geometry.transform(t, px))
          )
      }
    ]
  end

  defp outline(_, _), do: []

  @doc "The latest finished canvases, newest first, as feed items."
  def recent(limit \\ 200) do
    Repo.all(
      from j in Job,
        where: j.status == "done",
        order_by: [desc: j.finished_at],
        limit: ^limit,
        preload: [:atlas]
    )
    |> Enum.map(fn j ->
      atlas = Atlas.base(j.atlas)

      feed_item(
        atlas,
        Enum.at(atlas["sheets"], j.canvas_index),
        (j.result || %{})["parts"] || [],
        nil
      )
    end)
  end

  @doc """
  The atlas's parts in the shape of a `mix georef` report's canvases: each
  finished canvas's parts as the browser fitted them ("ok", else "failed"),
  and one "pending" entry for each canvas not done yet.
  """
  def parts(%Atlas{} = a) do
    jobs =
      Repo.all(
        from j in Job, where: j.atlas_id == ^a.id and j.status == "done", order_by: j.round
      )
      |> Enum.group_by(& &1.canvas_index)
      |> Map.new(fn {i, js} ->
        {i,
         Enum.reduce(js, fn j, best ->
           if fitted(j.result["parts"]) > fitted(best.result["parts"]), do: j, else: best
         end)}
      end)

    parts =
      a.canvases
      |> Enum.with_index()
      |> Enum.flat_map(fn {c, i} -> canvas_parts(c, jobs[i]) end)

    consistent(parts, jobs, a.canvases)
  end

  # Georef.Consistency on the browsers' fits: same-scale parts overlapping by
  # more than half on the ground are declined (unless a key map vouches for one)
  defp consistent(parts, jobs, canvases) do
    fitted =
      for {p, i} <- Enum.with_index(parts), p["status"] == "ok" do
        t = p["transform"]

        %{
          idx: i,
          status: :ok,
          canvas: %{id: p["id"]},
          part: p["part"],
          label: p["label"],
          method: :labels,
          mask: Enum.map(p["mask"], fn [x, y] -> {x, y} end),
          transform: %{a: t["a"], b: t["b"], tx: t["tx"], ty: t["ty"]},
          scale: :math.sqrt(t["a"] * t["a"] + t["b"] * t["b"])
        }
      end

    tokens_by_id =
      for {c, i} <- Enum.with_index(canvases), j = jobs[i], into: %{} do
        {c["id"],
         for t <- (j.result || %{})["tokens"] || [] do
           quad = Enum.map(t["quad"], fn [x, y] -> {x, y} end)
           {xs, ys} = Enum.unzip(quad)

           %{
             text: t["text"],
             score: t["score"],
             quad: quad,
             center: {Enum.sum(xs) / 4, Enum.sum(ys) / 4}
           }
         end}
      end

    losers =
      DpulCollections.Georef.Consistency.losers(fitted, &Map.get(tokens_by_id, &1.id, []))
      |> MapSet.new(fn {r, _} -> r.idx end)

    for {p, i} <- Enum.with_index(parts) do
      if i in losers, do: Map.merge(p, %{"status" => "failed", "conflict" => true}), else: p
    end
  end

  defp canvas_parts(c, job) do
    base = Map.take(c, ~w(id label service width height))
    full = [[0, 0], [c["width"], 0], [c["width"], c["height"]], [0, c["height"]]]

    case job do
      %Job{status: "done", result: %{"parts" => [_ | _] = ps}} ->
        for p <- ps do
          Map.merge(base, %{
            "label" =>
              if(length(ps) > 1, do: "#{c["label"]} (part #{p["part"]})", else: c["label"]),
            "part" => p["part"],
            "status" => if(p["status"] == "ok", do: "ok", else: "failed"),
            "mask" => p["mask"],
            "labels" => p["labels"] || [],
            "transform" => p["transform"],
            "printed_scale_ft" => p["printed_scale_ft"],
            "scale_m_per_px" => p["scale_m_per_px"]
          })
        end

      _ ->
        [Map.merge(base, %{"part" => 1, "status" => "pending", "mask" => full, "labels" => []})]
    end
  end

  def counts do
    Repo.all(from j in Job, group_by: j.status, select: {j.status, count(j.id)}) |> Map.new()
  end

  def atlas_counts do
    Repo.all(
      from j in Job,
        join: a in assoc(j, :atlas),
        group_by: [a.id, a.label, j.status],
        select: {a.id, a.label, j.status, count(j.id)}
    )
    |> Enum.group_by(fn {id, label, _, _} -> {id, label} end, fn {_, _, s, n} -> {s, n} end)
    |> Enum.map(fn {{id, label}, sn} -> %{id: id, label: label, counts: Map.new(sn)} end)
    |> Enum.sort_by(& &1.label)
  end
end
