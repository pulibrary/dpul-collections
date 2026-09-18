defmodule DpulCollectionsWeb.OcrController do
  use DpulCollectionsWeb, :controller
  alias DpulCollections.DistributedOcr.Host

  # Long polling, because that's what CircleCI and other things do and it's ez.
  def claim(conn, params) do
    client_id = params["client_id"] || "unknown"

    case Host.claim_job(client_id) do
      {:ok, job} ->
        conn
        |> put_status(:ok)
        |> json(%{
          job_id: job.id,
          image_url: job.image_url,
          mode: job.mode,
          manifest_url: job.manifest_url,
          manifest_label: job.manifest_label,
          page_label: job.page_label
        })

      {:error, :queue_empty} ->
        send_resp(conn, :no_content, "")
    end
  end

  # Clients report back OCR.
  def result(conn, %{"id" => job_id} = params) do
    attrs = %{
      client_id: params["client_id"],
      text: params["text"],
      model: params["model"],
      model_version: params["model_version"],
      duration_ms: params["duration_ms"]
    }

    {:ok, result} = Host.complete_job(job_id, attrs)

    conn
    |> put_status(:created)
    |> json(%{id: result.id})
  end
end
