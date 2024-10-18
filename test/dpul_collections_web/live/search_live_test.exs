defmodule DpulCollectionsWeb.SearchLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    doc1 = %{
      "id" => "ce6aa6c7-623f-4398-ba04-ba542a858e4f",
      "title_txtm" => ["Mehrdad"]
    }

    doc2 = %{
      "id" => "6c3367b1-344c-4dde-868e-c71192757c4a",
      "title_txtm" => ["Masih"]
    }

    doc3 = %{
      "id" => "097263fb-5beb-407b-ab36-b468e0489792",
      "title_txtm" => ["Hamed Javadzadeh"]
    }

    Solr.add([doc1, doc2, doc3])
    Solr.commit()
    on_exit(fn -> Solr.delete_all() end)
  end

  test "GET /search", %{conn: conn} do
    conn = get(conn, ~p"/search")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"underline text-lg\">Masih</div>"
    assert response =~ "<div class=\"underline text-lg\">Mehrdad</div>"
  end

  test "GET /search with blank q parameter", %{conn: conn} do
    conn = get(conn, ~p"/search?q=")
    response = html_response(conn, 200)
    assert response =~ "<div class=\"underline text-lg\">Masih</div>"
    assert response =~ "<div class=\"underline text-lg\">Mehrdad</div>"
  end

  test "searching filters results", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/search")

    response =
      view
      |> element("form")
      |> render_submit(%{"q" => "Hamed"})

    assert response =~ "<div class=\"font-bold text-lg\">Hamed Javadzadeh</div>"
  end
end
