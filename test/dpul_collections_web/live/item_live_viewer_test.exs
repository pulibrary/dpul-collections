defmodule DpulCollectionsWeb.ItemLiveViewerTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.ItemLive
  @endpoint DpulCollectionsWeb.Endpoint

  setup_all do
    Solr.add(
      [
        %{
          id: 1,
          description_txtm: ["A series of paintings of wizards"],
          title_txtm: ["Gandalf the Grey"],
          file_count_i: 30,
          ephemera_project_title_s: "Nonexistent Things",
          iiif_viewer_url_s:
            "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/viewer",
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ]
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "GET /item/{:id}/viewer", %{conn: conn} do
    conn = get(conn, ~p"/i/gandalf-the-grey/item/1/viewer")
    assert html_response(conn, 200) =~ "Digital Collections"
  end

  test "/item/{:id}/viewer displays and renders", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/i/gandalf-the-grey/item/1/viewer")

    assert view |> has_element?("h1", "Viewer")
  end

  test "/item/{:id}/viewer redirects when slug is missing", %{conn: conn} do
    conn = get(conn, "/item/1/viewer")
    assert redirected_to(conn, 302) == "/i/gandalf-the-grey/item/1/viewer"
  end

  test "/i/{:slug}/item/{:id}/viewer redirects when slug is incorrect",
       %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/1/viewer")
    assert redirected_to(conn, 302) == "/i/gandalf-the-grey/item/1/viewer"
  end
end
