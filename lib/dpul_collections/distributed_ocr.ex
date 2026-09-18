defmodule DpulCollections.DistributedOcr do
  import Ecto.Query
  alias DpulCollections.Repo
  alias DpulCollections.DistributedOcr.{Job, Result, ClientStatus}

  @work_ttl_seconds 600
  @idle_ttl_seconds 60

  # Queue every page in a manifest.
  def enqueue_pages(manifest_url, manifest_label, pages) do
    now = DateTime.utc_now()

    rows =
      Enum.map(pages, fn page ->
        %{
          image_url: page.image_url,
          page_label: page[:page_label],
          manifest_url: manifest_url,
          manifest_label: manifest_label,
          mode: "ocr",
          status: "queued",
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} = Repo.insert_all(Job, rows, on_conflict: :nothing, conflict_target: :image_url)
    count
  end

  # Claim the next available job, skipping any other workers have.
  def claim_next(client_id, lease_seconds) do
    now = DateTime.utc_now()
    lease = DateTime.add(now, lease_seconds, :second)

    next =
      from j in Job,
        where: j.status == "queued",
        # Order by ID, so workers grab pages in queue order.
        # TODO: Include a page number maybe?? The ascending ID may be fine.
        order_by: [asc: j.id],
        limit: 1,
        lock: "FOR UPDATE SKIP LOCKED",
        select: j.id

    # https://www.netdata.cloud/academy/update-skip-locked/
    {:ok, claimed} =
      Repo.transaction(fn ->
        case Repo.one(next) do
          nil ->
            nil

          id ->
            from(j in Job, where: j.id == ^id)
            |> Repo.update_all(
              set: [
                status: "claimed",
                claimed_by: client_id,
                claimed_at: now,
                lease_expires_at: lease,
                updated_at: now
              ]
            )

            Repo.get!(Job, id)
        end
      end)

    case claimed do
      %Job{} = job -> {:ok, job}
      nil -> :empty
    end
  end

  # Mark a job complete, pass attrs.
  def complete(job_id, attrs) do
    Repo.transaction(fn ->
      job = Repo.get(Job, job_id)

      denorm =
        case job do
          %Job{} = j ->
            %{
              image_url: j.image_url,
              manifest_url: j.manifest_url,
              manifest_label: j.manifest_label,
              page_label: j.page_label,
              ocr_job_id: j.id
            }

          nil ->
            %{}
        end

      result =
        %Result{}
        |> Result.changeset(Map.merge(attrs, denorm))
        |> Repo.insert!()

      if job do
        job
        |> Job.changeset(%{status: "done"})
        |> Repo.update!()
      end

      result
    end)
  end

  # Retry a job.
  def retry_page(image_url) do
    Repo.transaction(fn ->
      case Repo.get_by(Job, image_url: image_url) do
        nil ->
          false

        %Job{} = job ->
          from(r in Result, where: r.ocr_job_id == ^job.id) |> Repo.delete_all()
          requeue_jobs(from(j in Job, where: j.id == ^job.id))
          true
      end
    end)
  end

  # Retry every page in a manifest.
  def retry_manifest(manifest_url) do
    Repo.transaction(fn ->
      from(r in Result, where: r.manifest_url == ^manifest_url) |> Repo.delete_all()
      requeue_jobs(from(j in Job, where: j.manifest_url == ^manifest_url))
    end)
  end

  defp requeue_jobs(query) do
    {count, _} =
      Repo.update_all(query,
        set: [
          status: "queued",
          claimed_by: nil,
          claimed_at: nil,
          lease_expires_at: nil,
          updated_at: DateTime.utc_now()
        ]
      )

    count
  end

  # If a worker took too long, requeue it.
  def requeue_expired(now \\ DateTime.utc_now()) do
    {count, _} =
      from(j in Job,
        where: j.status == "claimed" and j.lease_expires_at < ^now
      )
      |> Repo.update_all(
        set: [status: "queued", claimed_by: nil, claimed_at: nil, lease_expires_at: nil]
      )

    count
  end

  # Get all the manifests and their current status from the database.
  # TODO: This kinda got away from me, I feel like I can do this better with
  # some better DB structure.
  def list_requested_manifests do
    covers =
      from(j in Job,
        distinct: [asc: j.manifest_url],
        order_by: [asc: j.manifest_url, asc: j.id],
        select: %{
          manifest_url: j.manifest_url,
          manifest_label: j.manifest_label,
          cover_image_url: j.image_url
        }
      )
      |> Repo.all()

    progress =
      from(j in Job,
        group_by: j.manifest_url,
        select: {j.manifest_url, %{total: count(j.id), last_activity: max(j.updated_at)}}
      )
      |> Repo.all()
      |> Map.new()

    done =
      from(r in Result, group_by: r.manifest_url, select: {r.manifest_url, count(r.id)})
      |> Repo.all()
      |> Map.new()

    covers
    |> Enum.map(fn cover ->
      stats = Map.get(progress, cover.manifest_url, %{total: 0, last_activity: nil})

      cover
      |> Map.merge(stats)
      |> Map.put(:done, Map.get(done, cover.manifest_url, 0))
    end)
    |> Enum.sort_by(& &1.last_activity, {:desc, DateTime})
  end

  # Get all the pages of a manifest.
  # TODO: Again, i should probably just store the book in the db as a proper
  # parent->child thing rather than associating by manifest URL key.
  def manifest_pages(manifest_url) do
    from(j in Job,
      left_join: r in Result,
      on: r.ocr_job_id == j.id,
      where: j.manifest_url == ^manifest_url,
      order_by: [asc: j.id],
      select: %{
        image_url: j.image_url,
        page_label: j.page_label,
        manifest_label: j.manifest_label,
        status: j.status,
        text: r.text,
        done: not is_nil(r.id)
      }
    )
    |> Repo.all()
  end

  def list_result_manifests do
    from(r in Result,
      group_by: [r.manifest_url, r.manifest_label],
      select: %{
        manifest_url: r.manifest_url,
        manifest_label: r.manifest_label,
        count: count(r.id),
        last_run_at: max(r.inserted_at)
      },
      order_by: [desc: max(r.inserted_at)]
    )
    |> Repo.all()
  end

  def results_for_manifest(manifest_url) do
    from(r in Result,
      where: r.manifest_url == ^manifest_url,
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  def recent_results(limit \\ 10) do
    from(r in Result, order_by: [desc: r.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  # Keep track of when a client messaged last, so we can mark it idle or not.
  # TODO: I wish I could figure out how to use Phoenix Presence here...
  def touch_client(client_id, attrs \\ %{}) do
    attrs = Map.merge(%{status: "idle", last_seen_at: DateTime.utc_now()}, attrs)

    %ClientStatus{}
    |> ClientStatus.changeset(Map.put(attrs, :client_id, client_id))
    |> Repo.insert!(
      on_conflict:
        {:replace, [:status, :image_url, :manifest_label, :page_label, :last_seen_at, :updated_at]},
      conflict_target: :client_id
    )
  end

  def connected_clients(now \\ DateTime.utc_now()) do
    work_cutoff = DateTime.add(now, -@work_ttl_seconds, :second)
    idle_cutoff = DateTime.add(now, -@idle_ttl_seconds, :second)

    from(c in ClientStatus,
      where:
        (c.status == "working" and c.last_seen_at > ^work_cutoff) or
          (c.status != "working" and c.last_seen_at > ^idle_cutoff),
      order_by: [asc: c.client_id]
    )
    |> Repo.all()
  end
end
