defmodule DpulCollectionsWeb.ItemLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup_all do
    Solr.add(SolrTestSupport.mock_solr_documents())

    Solr.add(
      [
        %{
          id: 1,
          title_txtm: "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii",
          display_date_s: "2022",
          page_count_i: 17
        },
        %{
          id: 2,
          title_txtm: "زلزلہ",
          display_date_s: "2024",
          page_count_i: 14
        }
      ],
      active_collection()
    )

    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "/item/{:id} redirects when title is recognized latin script", %{conn: conn} do
    conn = get(conn, "/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-urmărească-dez/item/1"
  end

  test "/item/{:id} does not redirect with a bad id", %{conn: conn} do
    conn = get(conn, "/item/badid1")
    assert conn.status == 200
  end

  test "/i/{:slug}/item/{:id} redirects when title is recognized latin script and slug is incorrect",
       %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-urmărească-dez/item/1"
  end

  test "/i/{:slug}/item/{:id} does not redirect when title is recognized latin script and slug is correct",
       %{conn: conn} do
    conn = get(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
    assert conn.status == 200
  end

  test "GET /i/{:slug}/item/{:id} response", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
    response = render(view)
    assert response =~ "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii"
    assert response =~ "2022"
    assert response =~ "17"
  end

  test "/i/{:slug}/item/{:id} does not redirect with a bad id", %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/badid1")
    response = html_response(conn, 200)
    assert response =~ "Item not found"
  end

  test "GET /item/{:id} response whith a bad id", %{conn: conn} do
    conn = get(conn, "/item/badid1")
    response = html_response(conn, 200)
    assert response =~ "Item not found"
  end
end
