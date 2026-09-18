defmodule DpulCollectionsWeb.OcrControllerTest do
  use DpulCollectionsWeb.ConnCase
  alias DpulCollections.DistributedOcr
  alias DpulCollections.DistributedOcr.{Job, Result}
  alias DpulCollections.Repo

  defp auth(conn, token \\ "test-token") do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  describe "POST /api/ocr/jobs/claim" do
    test "401s without a valid token", %{conn: conn} do
      assert conn |> post(~p"/api/ocr/jobs/claim", %{}) |> json_response(401)
      assert conn |> auth("nope") |> post(~p"/api/ocr/jobs/claim", %{}) |> json_response(401)
    end

    test "returns a queued job", %{conn: conn} do
      DistributedOcr.enqueue_pages("m1", "One", [%{image_url: "https://example.com/1.jpg"}])

      body =
        conn
        |> auth()
        |> post(~p"/api/ocr/jobs/claim", %{client_id: "c1"})
        |> json_response(200)

      assert body["image_url"] == "https://example.com/1.jpg"
      assert body["mode"] == "ocr"
      assert Repo.get(Job, body["job_id"]).claimed_by == "c1"
    end

    test "204s when the queue is empty", %{conn: conn} do
      assert conn |> auth() |> post(~p"/api/ocr/jobs/claim", %{}) |> response(204)
    end
  end

  describe "POST /api/ocr/jobs/:id/result" do
    test "persists a result and marks the job done", %{conn: conn} do
      DistributedOcr.enqueue_pages("m1", "One", [%{image_url: "https://example.com/1.jpg"}])
      {:ok, job} = DistributedOcr.claim_next("c1", 300)

      body =
        conn
        |> auth()
        |> post(~p"/api/ocr/jobs/#{job.id}/result", %{
          client_id: "c1",
          text: "hello",
          model: "m",
          model_version: "1",
          duration_ms: 5
        })
        |> json_response(201)

      result = Repo.get(Result, body["id"])
      assert result.text == "hello"
      assert result.client_id == "c1"
      assert Repo.get(Job, job.id).status == "done"
    end
  end
end
