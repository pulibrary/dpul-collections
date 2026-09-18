defmodule DpulCollections.DistributedOcr.HostTest do
  use DpulCollections.DataCase
  alias DpulCollections.DistributedOcr
  alias DpulCollections.DistributedOcr.{Host, Job, Result, ClientStatus}
  alias DpulCollections.Solr

  @expected_image_url "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/1500,/0/default.jpg"

  setup do
    sham =
      Sham.start()
      |> Sham.stub("GET", "/manifest/1/manifest", &manifest_stub/1)
      |> Sham.stub("GET", "/manifest/2/manifest", &list_label_manifest_stub/1)

    Solr.add(SolrTestSupport.mock_solr_documents(1, true, sham), active_collection())
    Solr.soft_commit(active_collection())
    {:ok, sham: sham, manifest_url: "http://localhost:#{sham.port}/manifest/1/manifest"}
  end

  describe ".ocr_manifest/1" do
    test "enqueues a queued job for every page, with manifest + page labels", %{
      manifest_url: manifest_url
    } do
      assert {:ok, 1} = Host.ocr_manifest(manifest_url)

      job = Repo.get_by(Job, image_url: @expected_image_url)
      assert job.status == "queued"
      assert job.manifest_url == manifest_url
      assert job.manifest_label == "Test"
      assert job.page_label == "default (11).jpg"
    end

    test "is idempotent per image_url", %{manifest_url: manifest_url} do
      assert {:ok, 1} = Host.ocr_manifest(manifest_url)
      assert {:ok, 0} = Host.ocr_manifest(manifest_url)
      assert Repo.aggregate(Job, :count) == 1
    end
  end

  describe ".claim_job/1" do
    test "hands out the queued job and marks it claimed", %{manifest_url: manifest_url} do
      Host.ocr_manifest(manifest_url)

      assert {:ok, job} = Host.claim_job("test-client")
      assert job.image_url == @expected_image_url

      claimed = Repo.get(Job, job.id)
      assert claimed.status == "claimed"
      assert claimed.claimed_by == "test-client"
    end

    test "returns :queue_empty when there's nothing to do" do
      assert {:error, :queue_empty} = Host.claim_job("test-client")
    end
  end

  describe "client presence" do
    test "claiming marks the client working; completing marks it idle", %{
      manifest_url: manifest_url
    } do
      Host.ocr_manifest(manifest_url)
      {:ok, job} = Host.claim_job("worker-a")

      assert %ClientStatus{status: "working", image_url: @expected_image_url} =
               Repo.get_by(ClientStatus, client_id: "worker-a")

      Host.complete_job(job.id, %{client_id: "worker-a", text: "x", model: "m"})
      assert %ClientStatus{status: "idle", image_url: nil} =
               Repo.get_by(ClientStatus, client_id: "worker-a")
    end

    test "a poll that finds nothing still registers the client as connected" do
      assert {:error, :queue_empty} = Host.claim_job("idle-worker")
      assert "idle-worker" in (DistributedOcr.connected_clients() |> Enum.map(& &1.client_id))
    end
  end

  describe ".complete_job/2" do
    test "records a result with metadata and marks the job done", %{manifest_url: manifest_url} do
      Host.ocr_manifest(manifest_url)
      {:ok, job} = Host.claim_job("test-client")

      assert {:ok, _result} =
               Host.complete_job(job.id, %{
                 client_id: "test-client",
                 text: "hello world",
                 model: "prithivMLmods/dots.mocr-GGUF/dots.mocr.Q4_K_M.gguf",
                 model_version: "1",
                 duration_ms: 42
               })

      result = Repo.get_by(Result, image_url: @expected_image_url)
      assert result.text == "hello world"
      assert result.client_id == "test-client"
      assert result.model_version == "1"
      assert result.manifest_label == "Test"

      assert Repo.get(Job, job.id).status == "done"
    end
  end

  describe "manifest parsing" do
    test "handles a list-form manifest label and a page with no label", %{sham: sham} do
      assert {:ok, 1} =
               Host.ocr_manifest("http://localhost:#{sham.port}/manifest/2/manifest")

      job = Repo.one(Job)
      assert job.manifest_label == "Listy"
      assert job.page_label == nil
    end
  end

  describe "long-poll waiters and the reaper" do
    test "a parked waiter is handed a job as soon as one is enqueued", %{manifest_url: manifest_url} do
      Application.put_env(:dpul_collections, Host, poll_ms: 2_000)
      on_exit(fn -> Application.put_env(:dpul_collections, Host, poll_ms: 50) end)

      task = Task.async(fn -> Host.claim_job("waiter") end)
      Process.sleep(50)
      Host.ocr_manifest(manifest_url)

      assert {:ok, %Job{image_url: @expected_image_url}} = Task.await(task)
    end

    test "the reaper requeues an expired claim" do
      job =
        %Job{}
        |> Job.changeset(%{
          image_url: "https://example.com/expired.jpg",
          status: "claimed",
          claimed_by: "gone",
          lease_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
        })
        |> Repo.insert!()

      send(Host, :reap)
      # Let the reaper run.
      Process.sleep(50)

      assert Repo.get(Job, job.id).status == "queued"
    end

    test "a flush while the queue is empty leaves the waiter parked", %{manifest_url: manifest_url} do
      Application.put_env(:dpul_collections, Host, poll_ms: 2_000)
      on_exit(fn -> Application.put_env(:dpul_collections, Host, poll_ms: 50) end)

      task = Task.async(fn -> Host.claim_job("waiter") end)
      Process.sleep(50)

      send(Host, :reap)
      Process.sleep(20)

      Host.ocr_manifest(manifest_url)
      assert {:ok, %Job{}} = Task.await(task)
    end

    test "a stray waiter_timeout for an unknown caller is ignored" do
      send(Host, {:waiter_timeout, {self(), make_ref()}})
      assert {:error, :queue_empty} = Host.claim_job("someone")
    end
  end

  def list_label_manifest_stub(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(200, JSON.encode!(list_label_manifest()))
  end

  def list_label_manifest do
    %{
      "label" => ["Listy"],
      "sequences" => [
        %{
          "canvases" => [
            %{
              "images" => [
                %{"resource" => %{"service" => %{"@id" => "https://iiif.test/abc"}}}
              ]
            }
          ]
        }
      ]
    }
  end

  def manifest_stub(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.merge_resp_headers([
      {"access-control-allow-origin", "*"},
      {"access-control-allow-methods", "GET"}
    ])
    |> Plug.Conn.delete_resp_header("Vary")
    |> Plug.Conn.delete_resp_header("Content-Encoding")
    |> Plug.Conn.resp(200, JSON.encode!(fake_manifest()))
  end

  def fake_manifest() do
    """
    {
    "@context": "http://iiif.io/api/presentation/2/context.json",
    "@type": "sc:Manifest",
    "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest",
    "label": "Test",
    "viewingHint": "individuals",
    "metadata": [
    {
      "label": "Title",
      "value": [
        "Test"
      ]
    },
    {
      "label": "Embargo Date",
      "value": [
        ""
      ]
    }
    ],
    "sequences": [
    {
      "@type": "sc:Sequence",
      "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/sequence/normal",
      "rendering": [
        {
          "@id": "https://figgy-staging.princeton.edu/catalog/eef217c2-bee1-4903-a5d8-9da430a08940/pdf",
          "label": "Download as PDF",
          "format": "application/pdf"
        }
      ],
      "canvases": [
        {
          "@type": "sc:Canvas",
          "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/canvas/07269645-02b1-4720-b99e-065aa9fb0887",
          "label": "default (11).jpg",
          "thumbnail": {
            "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/!200,150/0/default.jpg",
            "service": {
              "@context": "http://iiif.io/api/image/2/context.json",
              "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
              "profile": "http://iiif.io/api/image/2/level2.json"
            }
          },
          "rendering": [
            {
              "@id": "https://figgy-staging.princeton.edu/downloads/07269645-02b1-4720-b99e-065aa9fb0887/file/91fd958a-e01e-4c6b-86d4-ceaf6cd0da98",
              "label": "Download the original file",
              "format": "image/jpeg"
            }
          ],
          "width": 1000,
          "height": 1380,
          "images": [
            {
              "@type": "oa:Annotation",
              "motivation": "sc:painting",
              "resource": {
                "@type": "dctypes:Image",
                "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/1000,/0/default.jpg",
                "height": 1380,
                "width": 1000,
                "format": "image/jpeg",
                "service": {
                  "@context": "http://iiif.io/api/image/2/context.json",
                  "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
                  "profile": "http://iiif.io/api/image/2/level2.json"
                }
              },
              "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/image/07269645-02b1-4720-b99e-065aa9fb0887",
              "on": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/canvas/07269645-02b1-4720-b99e-065aa9fb0887"
            }
          ]
        }
      ],
      "viewingHint": "individuals"
    }
    ],
    "structures": [
    {
      "@type": "sc:Range",
      "@id": "https://figgy-staging.princeton.edu/concern/scanned_resources/eef217c2-bee1-4903-a5d8-9da430a08940/manifest/range/r8d5ce632-6be3-4f88-b951-de9a56b87509",
      "label": "Logical",
      "viewingHint": "top",
      "ranges": [],
      "canvases": []
    }
    ],
    "seeAlso": {
    "@id": "https://figgy-staging.princeton.edu/catalog/eef217c2-bee1-4903-a5d8-9da430a08940.jsonld",
    "format": "application/ld+json"
    },
    "license": "http://rightsstatements.org/vocab/CNE/1.0/",
    "thumbnail": {
    "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file/full/!200,150/0/default.jpg",
    "service": {
      "@context": "http://iiif.io/api/image/2/context.json",
      "@id": "https://iiif-cloud-staging.princeton.edu/iiif/2/79%2F5e%2F1c%2F795e1cefd4ba48128ea4ffbc1b45cd99%2Fintermediate_file",
      "profile": "http://iiif.io/api/image/2/level2.json"
    }
    },
    "logo": "https://figgy-staging.princeton.edu/pul_logo_icon.png"
    }
    """
  end
end
