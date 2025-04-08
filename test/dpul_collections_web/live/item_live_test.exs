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
          alternative_title_txtm: "Alternative Title",
          barcode_txtm: ["barcode"],
          box_number_txtm: ["box 1"],
          content_warning_txtm: ["content warning"],
          contributor_txtm: ["contributor"],
          creator_txtm: ["creator"],
          description_txtm: ["This is a test description"],
          display_date_s: "2022",
          file_count_i: 17,
          folder_number_txtm: ["1"],
          genre_txtm: ["genre"],
          geo_subject_txtm: ["geo subject"],
          geographic_origin_txtm: ["geographic origin"],
          height_txtm: ["200"],
          holding_location_txtm: ["holding location"],
          iiif_manifest_url_s:
            "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest",
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ],
          keywords_txtm: ["keyword"],
          language_txtm: ["language"],
          page_count_txtm: ["4"],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image2",
          provenance_txtm: ["provenance"],
          publisher_txtm: ["publisher"],
          rights_statement_txtm: ["No Known Copyright"],
          series_txtm: ["series"],
          sort_title_txtm: ["sort title"],
          subject_txtm: ["subject"],
          transliterated_title_txtm: ["transliterated title"],
          width_txtm: ["200"]
        },
        %{
          id: 2,
          title_txtm: "زلزلہ",
          display_date_s: "2024",
          file_count_i: 14,
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1"
        },
        %{
          id: 3,
          title_txtm: "اب كوئى جنگ نه هوگى نه كبهى رات گئے، خون كى آگ كو اشكوں سے بجهانا هوگا",
          display_date_s: "2022",
          file_count_i: 1,
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
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "/item/{:id} displays metadata fields", %{conn: conn} do
    conn = get(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

    {:ok, document} =
      html_response(conn, 200)
      |> Floki.parse_document()

    assert document |> Floki.find(~s{th:fl-contains("Date")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("2022")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Iiif manifest url")}) |> Enum.any?()

    assert document
           |> Floki.find(
             ~s{td:fl-contains("https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest")}
           )
           |> Enum.any?()

    assert document |> Floki.find(~s{th:fl-contains("Alternative title")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("Alternative Title")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Barcode")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("barcode")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Box number")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("box 1")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Content warning")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("content warning")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Contributor")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("contributor")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Creator")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("creator")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Description")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("This is a test description")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Folder number")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("1")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Genre")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("genre")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Geo subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("geo subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Geographic origin")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("geographic origin")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Height")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("200")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Holding location")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("holding location")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Keywords")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("keyword")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Language")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("language")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Page count")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("4")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Publisher")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("publisher")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Provenance")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("provenance")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Rights statement")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("No Known Copyright")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Series")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("series")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Transliterated title")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("transliterated title")}) |> Enum.any?()
    assert document |> Floki.find(~s{th:fl-contains("Width")}) |> Enum.any?()
    assert document |> Floki.find(~s{td:fl-contains("200")}) |> Enum.any?()

    # Does not display unconfigured fields
    assert document |> Floki.find(~s{th:fl-contains("Sort title")}) |> Enum.any?() == false
    assert document |> Floki.find(~s{td:fl-contains("sort title")}) |> Enum.any?() == false
  end

  test "/item/{:id} redirects when title is recognized latin script", %{conn: conn} do
    conn = get(conn, "/item/1")
    assert redirected_to(conn, 302) == "/i/învăţămîntul-trebuie-urmărească-dez/item/1"
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

    # Large thumbnail renders using thumbnail service url
    assert view
           |> has_element?(
             ".primary-thumbnail img[src='https://example.com/iiif/2/image2/full/525,800/0/default.jpg']"
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

  test "/i/{:slug}/item/{:id} 404s with a bad id", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/i/not-a-real-slug/item/badid1")
    end
  end

  test "GET /item/{:id} 404s with a bad id", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/item/badid1")
    end
  end
end
