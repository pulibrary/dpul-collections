defmodule DpulCollectionsWeb.Features.ItemViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "clicking the share button works", %{conn: conn} do
    conn
    |> visit("/i/document-1/item/1")
    |> stub_clipboard
    |> refute_has("#share-modal h3", text: "Share")
    |> click_button("Share")
    |> assert_has("#share-modal h3", text: "Share")
    |> click_button("Copy")
    |> assert_has("#share-modal button", text: "Copied")
    |> assert_has("#share-url", text: "http://localhost:4002/i/document1/item/1")
  end

  # Playwright has no clipboard permission, so just stub it out to prevent an
  # error in console.
  def stub_clipboard(conn) do
    conn
    |> unwrap(
      &Frame.evaluate(&1.frame_id, "window.navigator.clipboard.writeText = function() {}")
    )
  end

  test "links to and from metadata page", %{conn: conn} do
    conn
    |> visit("/i/document1/item/1")
    |> click_link("View all metadata for this item")
    |> assert_path("/i/document1/item/1/metadata")
    |> click_link("close")
    |> assert_path("/i/document1/item/1")
  end

  test "links to and from viewer page", %{conn: conn} do
    conn
    |> visit("/i/document1/item/1")
    |> click_link("#viewer-link", "View")
    |> assert_path("/i/document1/item/1/viewer")
    |> click_link("close")
    |> assert_path("/i/document1/item/1")
  end
end
