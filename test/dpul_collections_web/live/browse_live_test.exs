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

  test "browsing when there's a collection", %{conn: conn} do
    FiggyTestSupport.index_record_id_directly("f99af4de-fed4-4baa-82b1-6e857b230306")
    Solr.soft_commit()

    {:ok, view, _html} = live(conn, "/browse?r=0")

    refute element(view, ".browse-item") |> has_element?
  end

  test "browse from random", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(200), active_collection())
    Solr.commit(active_collection())

    {:ok, view, html} = live(conn, "/browse?r=0")

    initial_count =
      html
      |> Floki.parse_document!()
      |> Floki.find("#liked-items .liked-item")

    assert length(initial_count) == 0

    document = html |> Floki.parse_document!()
    random_items = document |> Floki.find("#browse-items .browse-item")

    # Make sure I can go to recommendations from the link
    {:ok, document} =
      view
      |> element("#browse-items .browse-item:first-child .like-header a")
      |> render_click()
      |> Floki.parse_document()

    assert Floki.text(document) =~ "Exploring items similar to"

    # Make sure clicking the element in thumbnail list goes to recommendations
    {:ok, document} =
      view
      |> element("#liked-items .liked-item:first-child")
      |> render_click()
      |> Floki.parse_document()

    selected_items = document |> Floki.find("#browse-items .browse-item")

    assert random_items != selected_items

    assert Floki.text(document) =~ "Exploring items similar to"

    # Add a second liked item.
    {:ok, document} =
      view
      |> element("#browse-items .browse-item:nth-child(2) .like-header a")
      |> render_click()
      |> Floki.parse_document()

    assert document |> Floki.find("#liked-items .liked-item") |> length == 2

    # TODO: unlike an item

    # Click randomize in liked items again
    assert view
           |> element("#liked-items *[aria-label=\"View Random Items\"]")
           |> render_click() =~ "Exploring a random set of items from our collections"
  end

  test "focused browse from link", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(90), active_collection())
    Solr.commit(active_collection())

    {:ok, _view, html} = live(conn, "/browse/focus/1")

    assert html =~ "Exploring items similar to"
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

  test "renders large and small thumbnails that link to records", %{conn: conn} do
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

    first_href =
      html
      |> Floki.parse_document!()
      |> Floki.find(".item-link")
      |> Enum.flat_map(&Floki.attribute(&1, "href"))
      |> Enum.at(0)

    assert first_href == "/i/documentn/item/n"
  end

  describe "item title truncation" do
    test "truncates when the title is > 70 characters", %{conn: conn} do
      Solr.add(
        [
          %{
            id: "n",
            title_txtm:
              "A pamphlet full of clever and hilarious sea shanties in many different languages",
            file_count_i: 3
          },
          %{
            id: "x",
            title_txtm: "A non-truncated title",
            file_count_i: 3
          },
          %{
            id: "y",
            title_txtm:
              "A title with enought words to truncate but happens to have a space as its 70th character",
            file_count_i: 3
          }
        ],
        active_collection()
      )

      Solr.commit(active_collection())

      {:ok, view, _html} = live(conn, "/browse?r=0")

      assert view
             |> element(
               "h2",
               "A pamphlet full of clever and hilarious sea shanties in many different..."
             )
             |> has_element?()

      assert view
             |> element(
               "h2",
               "A title with enought words to truncate but happens to have a space as..."
             )
             |> has_element?()

      assert view |> element("h2", "A non-truncated title") |> has_element?()
    end
  end

  test "page title", %{conn: conn} do
    {:ok, _, html} = live(conn, "/browse?r=0")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "Browse - Digital Collections"
  end
end
