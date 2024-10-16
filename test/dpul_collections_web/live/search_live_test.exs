defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    doc1 = %{
      "id" => "ce6aa6c7-623f-4398-ba04-ba542a858e4f",
      "title_ss" => ["Mehrdad"]
    }

    doc2 = %{
      "id" => "6c3367b1-344c-4dde-868e-c71192757c4a",
      "title_ss" => ["Masih"]
    }

    Solr.add([doc1, doc2])
    Solr.commit()
    on_exit(fn -> Solr.delete_all() end)
  end

  test "GET /search", %{conn: conn} do
    conn = get(conn, ~p"/search")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"font-bold text-lg\">Masih</div>"
    assert response =~ "<div class=\"font-bold text-lg\">Mehrdad</div>"
  end

  test "GET /search with blank q parameter", %{conn: conn} do
    conn = get(conn, ~p"/search?q=")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"font-bold text-lg\">Masih</div>"
    assert response =~ "<div class=\"font-bold text-lg\">Mehrdad</div>"
  end

  test "searching filters results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    response =
      view
      |> element("form")
      |> render_submit(%{"q" => "Masih"})

    assert response =~ "<div class=\"font-bold text-lg\">Masih</div>"
    assert !(response =~ "<div class=\"font-bold text-lg\">Mehrdad</div>")
  end
end
