defmodule DpulCollectionsWeb.Features.ItemViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(1, true), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  # Playwright has no clipboard permission, so just stub it out to prevent an
  # error in console.
  def stub_clipboard(conn) do
    conn
    |> unwrap(
      &Frame.evaluate(&1.frame_id, "window.navigator.clipboard.writeText = function() {}")
    )
  end

  describe "copy buttons" do
    test "clicking the share button works", %{conn: conn} do
      conn
      |> visit("/i/document-1/item/1")
      |> stub_clipboard
      |> refute_has("#share-modal h3", text: "Share")
      # opens the modal
      |> click_button("Share")
      |> assert_has("#share-modal h3", text: "Share")
      |> click_button("Copy")
      # changes the button text
      |> assert_has("#share-modal button", text: "Copied")
      |> assert_has("#share-url", text: "http://localhost:4002/i/document1/item/1")
      |> click_button("#close-share", "")
      # button text goes back after it's closed / opened again
      |> click_button("Share")
      |> assert_has("#share-modal button", text: "Copy")
    end

    test "item metdata pane can copy manifest url", %{conn: conn} do
      conn
      |> visit("/i/document1/item/1/metadata")
      |> stub_clipboard
      |> assert_has("#iiif-url", text: "#{TestServer.url()}/manifest/1/manifest")
      |> click_button("Copy")
      |> assert_has("button#iiif-url-copy", text: "Copied")
    end

    test "the 2 copy buttons don't interact", %{conn: conn} do
      conn
      |> visit("/i/document-1/item/1")
      |> stub_clipboard
      # use share copy button
      |> click_button("Share")
      |> click_button("Copy")
      |> assert_has("#share-modal button", text: "Copied")
      |> click_button("#close-share", "")
      # manifest url button has not been triggered
      |> click_link("View all metadata for this item")
      |> click_button("Copy")
      |> assert_has("button#iiif-url-copy", text: "Copied")
      |> click_link("close")
      # share copy button has not been triggered
      |> click_button("Share")
      |> assert_has("#share-modal button", text: "Copy")
    end
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
    stub_manifest(1)

    conn
    |> visit("/i/document1/item/1")
    |> click_link("#viewer-link", "View")
    |> assert_path("/i/document1/item/1/viewer/1")
    |> click_link("close")
    |> assert_path("/i/document1/item/1")
  end

  test "the metadata pane is not part of browser history", %{conn: conn} do
    conn
    |> visit("/search")
    |> click_link("Document-1")
    |> click_link("View all metadata for this item")
    |> assert_path("/i/document1/item/1/metadata")
    |> click_link("close")
    |> assert_path("/i/document1/item/1")
    |> go_back
    |> assert_path("/search")
  end

  test "the viewer pane is not part of browser history", %{conn: conn} do
    stub_manifest(1)

    conn
    |> visit("/search")
    |> click_link("Document-1")
    |> click_link("#viewer-link", "View")
    |> assert_path("/i/document1/item/1/viewer/1")
    |> click_link("close")
    |> assert_path("/i/document1/item/1")
    |> go_back
    |> assert_path("/search")
  end

  test "the viewer pane changes the URL when clicking a new item", %{conn: conn} do
    stub_manifest(1)

    conn
    |> visit("/item/1")
    |> click_link("#viewer-link", "View")
    |> assert_path("/i/document1/item/1/viewer/1")
    |> click_button("figcaption", "2")
    |> assert_path("/i/document1/item/1/viewer/2")

    stub_manifest(1)

    conn
    |> visit("/i/document/item/1/viewer")
    |> assert_path("/i/document1/item/1/viewer/1")
  end

  def go_back(conn) do
    conn
    |> unwrap(&Frame.evaluate(&1.frame_id, "window.history.back()"))
  end
end
