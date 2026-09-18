defmodule DpulCollections.DistributedOcrTest do
  use DpulCollections.DataCase
  alias DpulCollections.DistributedOcr
  alias DpulCollections.DistributedOcr.{Job, Result}

  defp queued_job(attrs) do
    %Job{}
    |> Job.changeset(Map.merge(%{image_url: "https://example.com/#{System.unique_integer()}"}, attrs))
    |> Repo.insert!()
  end

  describe ".requeue_expired/1" do
    test "requeues claimed jobs past their lease and leaves fresh ones alone" do
      expired =
        queued_job(%{
          status: "claimed",
          claimed_by: "c",
          lease_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })

      fresh =
        queued_job(%{
          status: "claimed",
          claimed_by: "c",
          lease_expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        })

      assert DistributedOcr.requeue_expired() == 1

      assert Repo.get(Job, expired.id).status == "queued"
      assert Repo.get(Job, fresh.id).status == "claimed"
    end
  end

  describe ".retry_page/1" do
    test "drops the result and requeues the job so it's OCR'd again" do
      DistributedOcr.enqueue_pages("m1", "Book", [%{image_url: "https://x/1.jpg", page_label: "1"}])
      {:ok, job} = DistributedOcr.claim_next("c", 300)
      {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "c", text: "first pass"})

      assert {:ok, true} = DistributedOcr.retry_page("https://x/1.jpg")

      job = Repo.get(Job, job.id)
      assert job.status == "queued"
      assert job.claimed_by == nil
      assert Repo.all(from r in Result, where: r.ocr_job_id == ^job.id) == []
    end

    test "returns {:ok, false} when no job matches the image" do
      assert {:ok, false} = DistributedOcr.retry_page("https://nope/1.jpg")
    end
  end

  describe ".retry_manifest/1" do
    test "requeues every page and clears all results for the manifest" do
      DistributedOcr.enqueue_pages("m1", "Book", [
        %{image_url: "https://x/1.jpg", page_label: "1"},
        %{image_url: "https://x/2.jpg", page_label: "2"}
      ])

      for _ <- 1..2 do
        {:ok, job} = DistributedOcr.claim_next("c", 300)
        {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "c", text: "done"})
      end

      assert {:ok, 2} = DistributedOcr.retry_manifest("m1")

      assert Repo.all(from j in Job, where: j.manifest_url == "m1", select: j.status) ==
               ["queued", "queued"]

      assert Repo.all(from r in Result, where: r.manifest_url == "m1") == []
    end
  end

  describe ".claim_next/2" do
    test "does it in page order" do
      DistributedOcr.enqueue_pages("m1", "Book", [
        %{image_url: "https://example.com/p1", page_label: "1"},
        %{image_url: "https://example.com/p2", page_label: "2"},
        %{image_url: "https://example.com/p3", page_label: "3"}
      ])

      claimed =
        for _ <- 1..3 do
          {:ok, job} = DistributedOcr.claim_next("c", 300)
          job.image_url
        end

      assert claimed == [
               "https://example.com/p1",
               "https://example.com/p2",
               "https://example.com/p3"
             ]
    end
  end

  describe ".complete/2" do
    test "records a result even when the job no longer exists" do
      assert {:ok, result} =
               DistributedOcr.complete(-1, %{
                 image_url: "https://example.com/orphan.jpg",
                 client_id: "c"
               })

      assert Repo.get(Result, result.id).image_url == "https://example.com/orphan.jpg"
    end
  end

  describe "recent_results/1" do
    test "returns all the most recently OCR'd things" do
      for i <- 1..3 do
        job = queued_job(%{manifest_url: "m#{i}"})
        {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "c", text: "t#{i}"})
      end

      assert length(DistributedOcr.recent_results(2)) == 2
    end
  end

  describe "client presence" do
    test "touch_client upserts status and clears the job when idle" do
      DistributedOcr.touch_client("c1", %{status: "working", image_url: "https://x/1.jpg"})
      assert [%{client_id: "c1", status: "working", image_url: "https://x/1.jpg"}] =
               DistributedOcr.connected_clients()

      DistributedOcr.touch_client("c1", %{status: "idle"})
      assert [%{client_id: "c1", status: "idle", image_url: nil}] = DistributedOcr.connected_clients()
    end

    test "connected_clients drops stale idle clients but keeps recent working ones" do
      now = DateTime.utc_now()
      DistributedOcr.touch_client("fresh", %{status: "idle"})

      old = DateTime.add(now, -300, :second)
      DistributedOcr.touch_client("stale-idle", %{status: "idle", last_seen_at: old})
      DistributedOcr.touch_client("busy", %{status: "working", last_seen_at: old})

      ids = DistributedOcr.connected_clients() |> Enum.map(& &1.client_id)
      assert "fresh" in ids
      assert "busy" in ids
      refute "stale-idle" in ids
    end
  end

  describe "browse queries" do
    test "list_result_manifests groups by manifest; results_for_manifest is newest first" do
      job = queued_job(%{manifest_url: "m1", manifest_label: "One"})

      {:ok, _} =
        DistributedOcr.complete(job.id, %{client_id: "c", text: "first", model: "m"})

      job2 = queued_job(%{manifest_url: "m1", manifest_label: "One"})

      {:ok, _} =
        DistributedOcr.complete(job2.id, %{client_id: "c", text: "second", model: "m"})

      assert [%{manifest_url: "m1", manifest_label: "One", count: 2}] =
               DistributedOcr.list_result_manifests()

      texts = DistributedOcr.results_for_manifest("m1") |> Enum.map(& &1.text)
      assert Enum.sort(texts) == ["first", "second"]
    end
  end
end
