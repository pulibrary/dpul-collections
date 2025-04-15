defmodule DpulCollectionsWeb.BrowseLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/browse")
    assert redirected_to(conn, 302) =~ "/browse?r="
  end

  test "click pin", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    {:ok, view, html} = live(conn, "/browse?r=0")

    initial_count =
      html
      |> Floki.parse_document!()
      |> Floki.find("#pinned-items .item")

    assert length(initial_count) == 0

    # Pin one
    {:ok, document} =
      view
      |> render_click("pin", %{"item_id" => "1"})
      |> Floki.parse_document()

    new_count =
      document
      |> Floki.find("#pinned-items .item")

    assert Enum.count(new_count) == 1

    pin_tracker =
      document
      |> Floki.find("#sticky-tools")

    assert pin_tracker |> Floki.text() |> String.trim("\n") |> String.trim() == "1"

    # Unpin it
    {:ok, document} =
      view
      |> render_click("pin", %{"item_id" => "1"})
      |> Floki.parse_document()

    new_count =
      document
      |> Floki.find("#pinned-items .item")

    assert Enum.count(new_count) == 0
  end

  test "click random button", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(90), active_collection())
    Solr.commit(active_collection())

    {:ok, view, html} = live(conn, "/browse?r=0")

    initial_order =
      html
      |> Floki.parse_document!()
      |> Floki.find(".item-link")
      |> Enum.flat_map(fn a -> Floki.attribute(a, "href") end)

    assert Enum.count(initial_order) == 90

    {:ok, document} =
      view
      |> render_click("randomize")
      |> Floki.parse_document()

    new_order =
      document
      |> Floki.find(".item-link")
      |> Enum.flat_map(fn a -> Floki.attribute(a, "href") end)

    assert initial_order != new_order
  end

  test "renders a link when there's a page count but no thumbnail", %{conn: conn} do
    Solr.add(
      [
        %{
          id: "n",
          title_txtm: "Document-n",
          file_count_i: 3
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())

    {:ok, view, _html} = live(conn, "/browse?r=0")

    view
    |> has_element?(".item-link")
  end

  test "renders a link when page count is zero and there's no thumbnail", %{conn: conn} do
    Solr.add(
      [
        %{
          id: "n",
          title_txtm: "Document-n",
          file_count_i: 0
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())

    {:ok, view, _html} = live(conn, "/browse?r=0")

    view
    |> has_element?(".item-link")
  end

  test "renders primary thumbnail only when there is only one image url", %{conn: conn} do
    Solr.add(
      [
        %{
          id: "n",
          title_txtm: "Document-n",
          file_count_i: 1,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1"
          ],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1"
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())

    {:ok, _view, html} = live(conn, "/browse?r=0")

    src =
      html
      |> Floki.parse_document!()
      |> Floki.find("img.thumbnail")
      |> Floki.attribute("src")

    assert src == ["https://example.com/iiif/2/image1/square/350,350/0/default.jpg"]
  end

  test "renders large and small thumbnails", %{conn: conn} do
    Solr.add(
      [
        %{
          id: "n",
          title_txtm: "Document-n",
          file_count_i: 2,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1"
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())

    {:ok, _view, html} = live(conn, "/browse?r=0")

    src =
      html
      |> Floki.parse_document!()
      |> Floki.find("img.thumbnail")
      |> Floki.attribute("src")

    assert src == [
             "https://example.com/iiif/2/image1/square/350,350/0/default.jpg",
             "https://example.com/iiif/2/image2/square/100,100/0/default.jpg"
           ]
  end
end
