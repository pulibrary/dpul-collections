defmodule DpulCollectionsWeb.OcrReaderLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.DistributedOcr

  defp enqueue_book do
    DistributedOcr.enqueue_pages("m1", "A Book", [
      %{image_url: "https://example.com/1.jpg", page_label: "p. 1"},
      %{image_url: "https://example.com/2.jpg", page_label: "p. 2"}
    ])
  end

  defp ocr_first_page(text) do
    {:ok, job} = DistributedOcr.claim_next("c", 300)
    {:ok, _} = DistributedOcr.complete(job.id, %{client_id: "c", text: text, model: "m"})
  end

  test "shows every page in one continuous scroll, text once read", %{conn: conn} do
    enqueue_book()
    ocr_first_page("hello from page one")

    {:ok, view, html} = live(conn, ~p"/ocr/read?#{[manifest: "m1"]}")

    assert html =~ "A Book"
    assert html =~ "1 of 2 pages read"
    # Every page image is on the page at once (continuous scroll).
    assert html =~ "https://example.com/1.jpg"
    assert html =~ "https://example.com/2.jpg"
    # The read page shows its transcription; the unread one shows a placeholder.
    assert render(view) =~ "hello from page one"
    assert render(view) =~ "been read yet"
  end

  test "live-refreshes when a new page is read", %{conn: conn} do
    enqueue_book()

    {:ok, view, _html} = live(conn, ~p"/ocr/read?#{[manifest: "m1"]}")
    assert render(view) =~ "0 of 2 pages read"

    ocr_first_page("fresh transcription")
    Phoenix.PubSub.broadcast(DpulCollections.PubSub, "ocr", :clients_changed)

    assert render(view) =~ "1 of 2 pages read"
    assert render(view) =~ "fresh transcription"
  end

  test "re-reading a page requeues it and drops its transcription", %{conn: conn} do
    enqueue_book()
    ocr_first_page("hello from page one")

    {:ok, view, _html} = live(conn, ~p"/ocr/read?#{[manifest: "m1"]}")
    assert render(view) =~ "1 of 2 pages read"

    view
    |> element("button[phx-value-image='https://example.com/1.jpg']")
    |> render_click()

    # The Host broadcasts :clients_changed, so the reader reloads: the page is
    # back to unread and its text is gone.
    assert render(view) =~ "0 of 2 pages read"
    refute render(view) =~ "hello from page one"
    assert DistributedOcr.manifest_pages("m1") |> Enum.all?(&(not &1.done))
  end

  test "re-reading the whole book requeues every page", %{conn: conn} do
    enqueue_book()
    ocr_first_page("hello from page one")

    {:ok, view, _html} = live(conn, ~p"/ocr/read?#{[manifest: "m1"]}")
    assert render(view) =~ "1 of 2 pages read"

    view |> element("button", "Re-read all pages") |> render_click()

    assert render(view) =~ "0 of 2 pages read"
    refute render(view) =~ "hello from page one"
  end

  test "redirects to the preview when no manifest is given", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/ocr"}}} = live(conn, ~p"/ocr/read")
  end
end
