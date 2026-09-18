defmodule DpulCollectionsWeb.OcrResultsLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.DistributedOcr
  alias DpulCollections.DistributedOcr.Job
  alias DpulCollections.Repo

  defp result_for(manifest_url, manifest_label, text) do
    job =
      %Job{}
      |> Job.changeset(%{
        image_url: "https://example.com/#{System.unique_integer()}.jpg",
        manifest_url: manifest_url,
        manifest_label: manifest_label
      })
      |> Repo.insert!()

    {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "c", text: text, model: "m"})
  end

  test "empty state when there are no results", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/ocr/results")
    assert html =~ "No OCR results yet."
  end

  test "lists manifests", %{conn: conn} do
    result_for("m1", "Labeled Manifest", "hello text")

    {:ok, view, _html} = live(conn, ~p"/ocr/results")
    assert render(view) =~ "Labeled Manifest"

    {:ok, drill, html} = live(conn, ~p"/ocr/results?#{[manifest: "m1"]}")
    assert html =~ "Labeled Manifest"
    assert render(drill) =~ "hello text"
  end

  test "falls back to the manifest url when there's no label", %{conn: conn} do
    result_for("m-no-label", nil, "text")

    {:ok, _view, html} = live(conn, ~p"/ocr/results?#{[manifest: "m-no-label"]}")
    assert html =~ "m-no-label"
  end
end
