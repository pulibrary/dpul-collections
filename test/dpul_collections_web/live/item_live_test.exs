defmodule DpulCollectionsWeb.ItemLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.ItemLive
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
          primary_thumbnail_h_w_ratio_f: 1.3256,
          provenance_txtm: ["provenance"],
          publisher_txtm: ["publisher"],
          rights_statement_txtm: ["No Known Copyright"],
          series_txtm: ["series"],
          sort_title_txtm: ["sort title"],
          subject_txtm: ["subject"],
          transliterated_title_txtm: ["transliterated title"],
          width_txtm: ["200"],
          ephemera_project_title_s: "Test Project",
          pdf_url_s:
            "https://figgy.example.com/concern/ephemera_folders/3da68e1c-06af-4d17-8603-fc73152e1ef7/pdf"
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
          image_canvas_ids_ss: [
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p1",
            "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
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
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image1",
          width_txtm: ["50"],
          height_txtm: ["20"]
        },
        %{
          id: "similar-to-1",
          title_txtm: "Similar Item Same Project",
          ephemera_project_title_s: "Test Project",
          genre_txtm: ["genre"],
          subject_txtm: ["subject"],
          width_txtm: ["10"],
          height_txtm: ["20"]
        },
        %{
          id: "similar-to-1-diff-project",
          title_txtm: "Similar Item Different Project",
          ephemera_project_title_s: "Different Project",
          genre_txtm: ["genre"],
          subject_txtm: ["subject"]
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

    assert document |> Floki.find(~s{dt:fl-contains("Creator of work")}) |> Enum.any?()
    assert document |> Floki.find(~s{.metadata *:fl-contains("creator")}) |> Enum.any?()
    assert document |> Floki.find(~s{dt:fl-contains("Geographic Origin")}) |> Enum.any?()
    assert document |> Floki.find(~s{.metadata *:fl-contains("geographic origin")}) |> Enum.any?()
    assert document |> Floki.find(~s{dt:fl-contains("Language")}) |> Enum.any?()
    assert document |> Floki.find(~s{.metadata *:fl-contains("language")}) |> Enum.any?()
    assert document |> Floki.find(~s{dt:fl-contains("Publisher")}) |> Enum.any?()
    assert document |> Floki.find(~s{.metadata *:fl-contains("publisher")}) |> Enum.any?()
    assert document |> Floki.find(~s{dt:fl-contains("Subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{.metadata *:fl-contains("subject")}) |> Enum.any?()
    assert document |> Floki.find(~s{*:fl-contains("Test Project")}) |> Enum.any?()

    # Does not display unconfigured fields
    assert document |> Floki.find(~s{dt:fl-contains("Sort title")}) |> Enum.any?() == false
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

  describe "GET /i/{:slug}/item/{:id}" do
    test "renders values and thumbnails", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
      response = render(view)
      assert response =~ "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii"
      assert response =~ "2022"
      assert response =~ "17"
      assert response =~ "This is a test description"
      # Thumbnails render with link to viewer
      assert view
             |> has_element?(
               "img[src='https://example.com/iiif/2/image1/full/350,465/0/default.jpg']"
             )

      assert view
             |> has_element?("a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/1']")

      assert view
             |> has_element?(
               "img[src='https://example.com/iiif/2/image2/full/350,465/0/default.jpg']"
             )

      assert view
             |> has_element?("a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/2']")

      # Large thumbnail renders using thumbnail service url
      assert view
             |> has_element?(
               ".primary-thumbnail img[src='https://example.com/iiif/2/image2/full/!453,600/0/default.jpg']"
             )

      # Large thumbnail has default width
      assert view
             |> has_element?(".primary-thumbnail img[width='453']")

      # Large thumbnail has calculated height
      assert view
             |> has_element?(".primary-thumbnail img[height='600']")

      assert view
             |> has_element?(
               ".primary-thumbnail a[href='https://figgy.example.com/concern/ephemera_folders/3da68e1c-06af-4d17-8603-fc73152e1ef7/pdf']",
               "Download"
             )

      # Renders when there's no description
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")
      response = render(view)
      assert response =~ "زلزلہ"
    end

    test "displays size when using the button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      html =
        view
        |> element(".metadata button", "Size")
        |> render_click()

      assert html =~ "200 cm."
      assert html =~ "Letter Paper"
    end

    test "doesnt display letter paper unless the thing is at least letter paper size", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, "/i/اب-كوئى-جنگ-نه-هوگى/item/3")

      html =
        view
        |> element(".metadata button", "Size")
        |> render_click()

      assert html =~ "20 cm."
      refute html =~ "Letter Paper"

      {:ok, view, _html} = live(conn, "/i/similar-item-same-project/item/similar-to-1")

      html =
        view
        |> element(".metadata button", "Size")
        |> render_click()

      assert html =~ "10 cm."
      refute html =~ "Letter Paper"
    end

    test "doesn't have a size button when there's no size metadata", %{conn: conn} do
      {:ok, view, html} = live(conn, "/i/زلزلہ/item/2")

      refute view
             |> has_element?(".metadata button", "Size")

      refute html =~ "Letter Paper"
    end

    test "doesn't display a pdf for resources with no pdf permission", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")
      response = render(view)

      assert response =~ "زلزلہ"
      assert response =~ "No PDF Available"
    end

    test "shows some related items", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      assert view |> has_element?("#related-same-project h2 a", "Similar Item Same Project")

      assert view
             |> has_element?("#related-different-project h2 a", "Similar Item Different Project")
    end

    test "doesn't show collection related items for items without a collection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")

      refute view |> has_element?("#related-same-project")
    end
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

  test ".rights_path converts strings to image paths" do
    assert ItemLive.rights_path("Copyright Not Evaluated") == "copyright-not-evaluated.svg"
    assert ItemLive.rights_path("CC-BY 4.0") == "ccby-40.svg"
    assert ItemLive.rights_path(["CC-BY 4.0"]) == "ccby-40.svg"

    assert ItemLive.rights_path("In Copyright - Rights-holder(s) Unlocatable or Unidentifiable") ==
             "in-copyright--rightsholders-unlocatable-or-unidentifiable.svg"

    assert ItemLive.rights_path("In Copyright - Educational Use Permitted") ==
             "in-copyright--educational-use-permitted.svg"
  end

  describe "GET /i/{:slug}/item/{:id}/viewer" do
    test "changed_canvas_event doesn't do anything if not on the viewer pane", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")

      view
      |> render_hook("changedCanvas", %{
        "canvas_id" => "https://iiif.io/api/cookbook/recipe/0001-mvm-image/canvas/p2"
      })

      refute_navigation(view, :patch, "/i/زلزلہ/item/2/viewer/2")
    end
  end

  test "page title", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()

    assert title == "\n      زلزلہ - Digital Collections\n    "

    {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2/metadata")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()

    assert title == "\n      Metadata - زلزلہ - Digital Collections\n    "

    {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2/viewer/0")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()

    assert title == "\n      Viewer - زلزلہ - Digital Collections\n    "
  end

  # Copied from
  # https://github.com/phoenixframework/phoenix_live_view/blob/v1.0.17/lib/phoenix_live_view/test/live_view_test.ex#L1478C1-L1492C6
  # because we don't have a refute_patched. Remove when
  # https://github.com/phoenixframework/phoenix_live_view/issues/3863 is closed.
  defp refute_navigation(view = %{proxy: {ref, topic, _}}, kind, to) do
    receive do
      {^ref, {^kind, ^topic, %{to: new_to}}} when new_to == to or to == nil ->
        message =
          "expected #{inspect(view.module)} not to #{kind} to #{inspect(to)}, "

        raise ArgumentError, message <> "but got a #{kind} to #{inspect(new_to)}"
    after
      0 -> :ok
    end
  end
end
