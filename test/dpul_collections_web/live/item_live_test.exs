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
          page_count_i: 1
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
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-să-urmărească/item/1"
  end

  test "/item/{:id} does not redirect when title is not recognized latin script", %{conn: conn} do
    conn = get(conn, "/item/2")
    assert conn.status == 200
  end

  test "/item/{:id} does not redirect with a bad id", %{conn: conn} do
    conn = get(conn, "/item/badid1")
    assert conn.status == 200
  end

  test "/i/{:slug}/item/{:id} redirects when title is recognized latin script and slug is incorrect",
       %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-să-urmărească/item/1"
  end

  test "/i/{:slug}/item/{:id} redirects when title is unrecognized latin script", %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/2")
    assert redirected_to(conn, 302) == "/item/2"
  end

  test "/i/{:slug}/item/{:id} does not redirect when title is recognized latin script and slug is correct",
       %{conn: conn} do
    conn = get(conn, "/i/învăţămîntul-trebuie-să-urmărească/item/1")
    assert conn.status == 200
  end

  test "GET /item/{:id} response", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/item/2")
    response = render(view)
    assert response =~ "زلزلہ"
    assert response =~ "2024"
    assert response =~ "14"
  end

  test "/i/{:slug}/item/{:id} does not redirect with a bad id", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/i/not-a-real-slug/item/badid1")
    end
  end

  test "GET /item/{:id} response whith a bad id retuns a 404", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/item/badid1")
    end
  end
end
