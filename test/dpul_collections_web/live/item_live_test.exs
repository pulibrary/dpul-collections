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
          page_count_i: 17,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ],
          description_txtm: ["This is a test description"]
        },
        %{
          id: 2,
          title_txtm: "زلزلہ",
          display_date_s: "2024",
          page_count_i: 14,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ]
        },
        %{
          id: 3,
          title_txtm: "اب كوئى جنگ نه هوگى نه كبهى رات گئے، خون كى آگ كو اشكوں سے بجهانا هوگا",
          display_date_s: "2022",
          page_count_i: 1,
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

  test "/item/{:id} redirects when title is recognized latin script", %{conn: conn} do
    conn = get(conn, "/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-urmărească-dez/item/1"
  end

  test "/item/{:id} does not redirect with a bad id", %{conn: conn} do
    conn = get(conn, "/item/badid1")
    assert conn.status == 200
  end

  test "/i/{:slug}/item/{:id} redirects when slug is incorrect",
       %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-urmărească-dez/item/1"
  end

  test "/i/{:slug}/item/{:id} does not redirect when slug is correct",
       %{conn: conn} do
    conn = get(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
    assert conn.status == 200
  end

  test "/i/{:slug}/item/{:id} does not redirect with url encoded arabic slug",
       %{conn: conn} do
    conn =
      get(
        conn,
        "/i/%D8%A7%D8%A8-%D9%83%D9%88%D8%A6%D9%89-%D8%AC%D9%86%DA%AF-%D9%86%D9%87-%D9%87%D9%88%DA%AF%D9%89/item/3"
      )

    assert conn.status == 200
  end

  test "GET /i/{:slug}/item/{:id} response", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
    response = render(view)
    assert response =~ "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii"
    assert response =~ "2022"
    assert response =~ "17"
    assert response =~ "This is a test description"
    # Thumbnails render.
    assert view
           |> has_element?(
             "img[src='https://example.com/iiif/2/image1/full/350,465/0/default.jpg']"
           )

    assert view
           |> has_element?(
             "img[src='https://example.com/iiif/2/image2/full/350,465/0/default.jpg']"
           )

    # Download links for each thumbnail
    assert view
           |> has_element?(
             "a[href='https://example.com/iiif/2/image1/full/full/0/default.jpg']",
             "Download"
           )

    assert view
           |> has_element?(
             "a[href='https://example.com/iiif/2/image2/full/full/0/default.jpg']",
             "Download"
           )

    # Large thumbnail renders
    assert view
           |> has_element?(
             ".primary-thumbnail img[src='https://example.com/iiif/2/image1/full/525,800/0/default.jpg']"
           )

    assert view
           |> has_element?(
             ".primary-thumbnail a[href='https://figgy.example.com/catalog/1/pdf']",
             "Download PDF"
           )

    # Renders when there's no description
    {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")
    response = render(view)
    assert response =~ "زلزلہ"
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
