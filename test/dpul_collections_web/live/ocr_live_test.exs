defmodule DpulCollectionsWeb.OcrLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.DistributedOcr

  defp enqueue_book do
    DistributedOcr.enqueue_pages("m1", "A Manifest", [
      %{image_url: "https://example.com/1.jpg", page_label: "p. 1"},
      %{image_url: "https://example.com/2.jpg", page_label: "p. 2"}
    ])
  end

  test "shows a cover per requested manifest with reading progress", %{conn: conn} do
    enqueue_book()
    {:ok, job} = DistributedOcr.claim_next("laptop-1", 300)
    {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "laptop-1", text: "done text", model: "m"})

    {:ok, _view, html} = live(conn, ~p"/ocr")

    assert html =~ "A Manifest"
    # The cover is the first enqueued page.
    assert html =~ "https://example.com/1.jpg"
    assert html =~ "1 of 2 pages read"
    # Cover links to the reader for that book.
    assert html =~ "/ocr/read?manifest=m1"
  end

  test "empty state when no books requested", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/ocr")
    assert html =~ "No books have been requested yet."
  end

  test "flashes an error for an unreadable manifest URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ocr")

    html =
      view
      |> form("form[phx-submit=add_manifest]", manifest: "https://nope.invalid/manifest")
      |> render_submit()

    assert html =~ "Couldn&#39;t add that manifest"
  end

  test "refreshes when a book is requested (:clients_changed broadcast)", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ocr")
    refute render(view) =~ "A Manifest"

    enqueue_book()
    Phoenix.PubSub.broadcast(DpulCollections.PubSub, "ocr", :clients_changed)

    assert render(view) =~ "A Manifest"
  end
end
