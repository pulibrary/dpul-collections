defmodule DpulCollectionsWeb.HomeLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Digital Collections"
  end

  test "search form redirect", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    assert view
           |> element("form")
           |> render_submit(%{"q" => "cats"}) ==
             {:error, {:live_redirect, %{kind: :push, to: "/search?q=cats"}}}
  end

  describe "recent item blocks" do
    test "renders 3 cards", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.commit(active_collection())

      {:ok, _view, html} = live(conn, "/")

      links =
        html
        |> Floki.parse_document!()
        |> Floki.find(".item-link")
        |> Enum.flat_map(fn a -> Floki.attribute(a, "href") end)

      assert Enum.count(links) == 3
    end

    test "link to recently updated", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(100), active_collection())
      Solr.commit(active_collection())

      {:ok, view, _} = live(conn, "/")

      {:ok, document} =
        view
        |> element("#recent-items .btn-arrow")
        |> render_click()
        |> follow_redirect(conn, "/search?sort_by=recently_updated")
        |> elem(2)
        |> Floki.parse_document()

      assert document
             |> Floki.find(~s{a[href="/i/document1/item/1"]})
             |> Enum.empty?()

      assert document
             |> Floki.find(~s{a[href="/i/document100/item/100"]})
             |> Enum.any?()
    end

    test "recently updated thumbnails link to record", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(3), active_collection())
      Solr.commit(active_collection())

      {:ok, view, _} = live(conn, "/")

      html = render(view)

      first_href =
        html
        |> Floki.parse_document!()
        |> Floki.find(".item-link")
        |> Enum.flat_map(&Floki.attribute(&1, "href"))
        |> Enum.at(0)

      assert first_href == "/i/document3/item/3"
    end
  end

  test "link to filters", %{conn: conn} do
    {:ok, _, _} = live(conn, "/")

    ["photographs", "posters", "pamphlets"]
    |> Enum.each(fn genre ->
      {:ok, view, _} = live(conn, "/")

      assert view
             |> element("#main-content a", genre)
             |> render_click() ==
               {:error, {:redirect, %{to: "/search?filter[genre]=#{genre}"}}}
    end)
  end

  test "link to browse", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    assert view
           |> element("#main-content a", "Explore")
           |> render_click() ==
             {:error, {:redirect, %{to: "/browse"}}}
  end

  test "page title", %{conn: conn} do
    {:ok, _, html} = live(conn, "/")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "Digital Collections"
  end
end
