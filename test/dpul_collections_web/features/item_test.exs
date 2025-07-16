defmodule DpulCollectionsWeb.Features.ItemViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  alias PhoenixTest.Playwright
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    sham = Sham.start()
    Solr.add(SolrTestSupport.mock_solr_documents(1, true, sham), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
    {:ok, sham: sham}
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
      |> refute_has("#share-modal")
      # opens the modal
      |> click_button("Share")
      |> assert_has("#share-modal h3", text: "Share this item")
      |> click_button("Copy")
      # changes the button text
      |> assert_has("#share-modal button", text: "Copied")
      |> assert_has("#share-modal-value", text: "http://localhost:4002/i/document1/item/1")
      |> click_button("close")
      |> refute_has("#share-modal")
      # button text goes back after it's closed / opened again
      |> click_button("Share")
      |> assert_has("#share-modal button", text: "Copy")
    end

    test "item metdata pane can copy manifest url", %{conn: conn, sham: sham} do
      conn
      |> visit("/i/document1/item/1/metadata")
      |> stub_clipboard
      |> assert_has("#iiif-url", text: "http://localhost:#{sham.port}/manifest/1/manifest")
      |> click_button("Copy")
      |> assert_has("button#iiif-url-copy", text: "Copied")
    end

    test "viewer pane can copy current url", %{conn: conn} do
      conn
      |> visit("/i/document1/item/1/viewer")
      |> stub_clipboard
      |> refute_has("#viewer-share-modal")
      # opens the modal
      |> click_button("Share")
      |> assert_has("#viewer-share-modal h3", text: "Share this image")
      |> assert_has("#viewer-share-modal-value",
        text: "http://localhost:4002/i/document1/item/1/viewer/1"
      )
      |> click_button("Copy")
      |> assert_has("button#viewer-share-modal-value-copy", text: "Copied")
      |> click_button("close")
      |> refute_has("#viewer-share-modal")
      # Escape closes the modal
      |> click_button("Share")
      |> assert_has("#viewer-share-modal h3", text: "Share this image")
      |> Playwright.press("#viewer-share-modal", "Escape")
      |> refute_has("#viewer-share-modal")
      |> assert_path("/i/document1/item/1/viewer/1")
      |> assert_has("#viewer-pane")
      # can still also close the viewer pane
      |> Playwright.press("#viewer-pane", "Escape")
      |> assert_path("/i/document1/item/1")
    end

    test "the 2 copy buttons don't interact", %{conn: conn} do
      conn
      |> visit("/i/document-1/item/1")
      |> stub_clipboard
      # use share copy button
      |> click_button("Share")
      |> click_button("Copy")
      |> assert_has("#share-modal button", text: "Copied")
      |> click_button("close")
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
    conn
    |> visit("/item/1")
    |> click_link("#viewer-link", "View")
    |> assert_path("/i/document1/item/1/viewer/1")
    |> click_button("figcaption", "2")
    |> assert_path("/i/document1/item/1/viewer/2")

    # It defaults to the first page Clover opens if not given one.
    conn
    |> visit("/i/document/item/1/viewer")
    |> assert_path("/i/document1/item/1/viewer/1")
  end

  test "item page is accessible", %{conn: conn} do
    conn
    |> visit("/i/document-1/item/1")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  test "metadata page is accessible", %{conn: conn} do
    conn
    |> visit("/i/document1/item/1/metadata")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  test "viewer page is accessible", %{conn: conn} do
    conn
    |> visit("/i/document1/item/1/viewer/1")
    |> unwrap(&TestUtils.assert_a11y(&1, RoleImgAltFilter))
  end

  def go_back(conn) do
    conn
    |> unwrap(&Frame.evaluate(&1.frame_id, "window.history.back()"))
  end
end
