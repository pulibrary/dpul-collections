defmodule DpulCollectionsWeb.ItemLiveMetadataTest do
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

  test "/item/{:id}/metadata displays all the metadata fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/i/gandalf-the-grey/item/1/viewer")

    assert view |> has_element?("h1", "Viewer")
  end
end
