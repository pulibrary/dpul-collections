defmodule DpulCollectionsWeb.ItemLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.ItemLive
  import DpulCollections.AccountsFixtures
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents())

    Solr.add(
      [
        %{
          id: 1,
          title_txtm: "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii",
          alternative_title_txtm: "Alternative Title",
          barcode_txtm: ["barcode"],
          box_number_txtm: ["box 1"],
          content_warning_s: "content warning",
          contributor_txt_sort: ["contributor"],
          creator_txt_sort: ["creator"],
          description_txtm: ["This is a test description"],
          display_date_s: "2022",
          file_count_i: 17,
          folder_number_txtm: ["1"],
          genre_txt_sort: ["genre"],
          geo_subject_txt_sort: ["geo subject"],
          geographic_origin_txt_sort: ["geographic origin"],
          height_txtm: ["200"],
          holding_location_txt_sort: ["holding location"],
          iiif_manifest_url_s:
            "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest",
          image_service_urls_ss: [
            "https://example.com/iiif/2/image1",
            "https://example.com/iiif/2/image2"
          ],
          keywords_txt_sort: ["keyword"],
          language_txt_sort: ["language"],
          page_count_txtm: ["4"],
          primary_thumbnail_service_url_s: "https://example.com/iiif/2/image2",
          primary_thumbnail_h_w_ratio_f: 1.3256,
          provenance_txtm: ["provenance"],
          publisher_txt_sort: ["publisher"],
          rights_statement_txtm: ["No Known Copyright"],
          series_txt_sort: ["series"],
          sort_title_txtm: ["sort title"],
          subject_txt_sort: ["subject"],
          transliterated_title_txtm: ["transliterated title"],
          width_txtm: ["200"],
          ephemera_project_title_s: "Test Project",
          ephemera_project_id_s: "similar-to-1-is-a-project",
          tagline_txtm: "This is a tagline.",
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
          file_count_i: 1,
          ephemera_project_title_s: "Test Project",
          genre_txt_sort: ["genre"],
          subject_txt_sort: ["subject"],
          width_txtm: ["10"],
          height_txtm: ["20"],
          description_txtm:
            "This is a really really really long description that has a bunch of information which is too much for a bluesky tweet and so probably we should truncate it. I'm going to keep on rambling here, so that my stream of consciousness is caught in this test."
        },
        %{
          id: "similar-to-1-diff-project",
          file_count_i: 1,
          title_txtm: "Similar Item Different Project",
          ephemera_project_title_s: "Different Project",
          genre_txt_sort: ["genre"],
          subject_txt_sort: ["subject"]
        },
        %{
          id: "similar-to-1-is-a-project",
          title_txtm: "Test Project",
          tagline_txtm: "This is a tagline.",
          description_txtm: ["This is a test description"],
          authoritative_slug_s: "project",
          resource_type_s: "collection"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())
    :ok
  end

  describe "url paths and routing" do
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

  describe "og:metadata" do
    test "displays og:metadata fields in the header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      {:ok, document} = Floki.parse_document(html)

      assert document
             |> Floki.find(
               ~s{meta[property="og:title"][content="Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii"]}
             )
             |> Enum.any?()

      assert document
             |> Floki.find(
               ~s{meta[property="og:image"][content="https://example.com/iiif/2/image2/full/!453,600/0/default.jpg"]}
             )
             |> Enum.any?()

      assert document
             |> Floki.find(
               ~s{meta[property="og:description"][content="This is a test description"]}
             )
             |> Enum.any?()

      assert document
             |> Floki.find(~s{meta[property="og:url"][content="http://localhost:4002/item/1"]})
             |> Enum.any?()
    end

    test "can handle no description", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2")

      {:ok, document} = Floki.parse_document(html)

      assert document |> Floki.find(~s{meta[property="og:title"][content="زلزلہ"]}) |> Enum.any?()

      assert document
             |> Floki.find(
               ~s{meta[property="og:image"][content="https://example.com/iiif/2/image1/full/!453,800/0/default.jpg"]}
             )
             |> Enum.any?()

      refute document |> Floki.find(~s{meta[property="og:description"]}) |> Enum.any?()

      assert document
             |> Floki.find(~s{meta[property="og:url"][content="http://localhost:4002/item/2"]})
             |> Enum.any?()
    end

    test "can handle long descriptions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/i/similar-item-same-project/item/similar-to-1")

      {:ok, document} = Floki.parse_document(html)

      assert document
             |> Floki.find(
               ~s{meta[property="og:description"][content="This is a really really really long description that has a bunch of information which is too much for a bluesky tweet and so probably we should truncate it. I'm going to keep on rambling here, so t..."]}
             )
             |> Enum.any?()
    end
  end

  describe "page display" do
    test "displays metadata fields", %{conn: conn} do
      conn = get(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      {:ok, document} =
        html_response(conn, 200)
        |> Floki.parse_document()

      assert document |> Floki.find(~s{dt:fl-contains("Creator of work")}) |> Enum.any?()
      assert document |> Floki.find(~s{.metadata *:fl-contains("creator")}) |> Enum.any?()
      assert document |> Floki.find(~s{dt:fl-contains("Geographic Origin")}) |> Enum.any?()

      assert document
             |> Floki.find(~s{.metadata *:fl-contains("geographic origin")})
             |> Enum.any?()

      assert document |> Floki.find(~s{dt:fl-contains("Geographic Subject")}) |> Enum.any?()

      assert document
             |> Floki.find(~s{.metadata *:fl-contains("geo subject")})
             |> Enum.any?()

      assert document |> Floki.find(~s{dt:fl-contains("Language")}) |> Enum.any?()
      assert document |> Floki.find(~s{.metadata *:fl-contains("language")}) |> Enum.any?()
      assert document |> Floki.find(~s{dt:fl-contains("Publisher")}) |> Enum.any?()
      assert document |> Floki.find(~s{.metadata *:fl-contains("publisher")}) |> Enum.any?()
      assert document |> Floki.find(~s{dt:fl-contains("Subject")}) |> Enum.any?()
      assert document |> Floki.find(~s{.metadata *:fl-contains("subject")}) |> Enum.any?()
      assert document |> Floki.find(~s{*:fl-contains("Test Project")}) |> Enum.any?()
      assert document |> Floki.find(~s{*:fl-contains("This is a tagline.")}) |> Enum.any?()

      # Does not display unconfigured fields
      assert document |> Floki.find(~s{dt:fl-contains("Sort title")}) |> Enum.any?() == false
    end

    test "renders values, thumbnails, and links", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")
      response = render(view)
      assert response =~ "Învăţămîntul trebuie să urmărească dezvoltarea deplină a personalităţii"
      assert response =~ "2022"
      assert response =~ "17"
      assert response =~ "This is a test description"

      # Small thumbnails render with links to viewer
      assert view
             |> has_element?(
               "a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/1'] img[src='https://example.com/iiif/2/image1/square/!350,465/0/default.jpg']"
             )

      assert view
             |> has_element?(
               "a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/2'] img[src='https://example.com/iiif/2/image2/square/!350,465/0/default.jpg']"
             )

      # Large thumbnail links to the correct image when it's not the first image
      assert view
             |> has_element?(
               ".primary-thumbnail a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/2'] img[src='https://example.com/iiif/2/image2/full/!453,600/0/default.jpg']"
             )

      # Large thumbnail has default width
      assert view
             |> has_element?(".primary-thumbnail img[width='453']")

      # Large thumbnail has calculated height
      assert view
             |> has_element?(".primary-thumbnail img[height='600']")

      assert view
             |> has_element?(
               ".thumbnail-buttons a[href='https://figgy.example.com/concern/ephemera_folders/3da68e1c-06af-4d17-8603-fc73152e1ef7/pdf']",
               "Download PDF"
             )

      # Page renders when there's no description
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")
      response = render(view)
      assert response =~ "زلزلہ"
    end

    test "doesn't display a pdf for resources with no pdf permission", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")
      response = render(view)

      assert response =~ "زلزلہ"
      assert response =~ "No PDF Available"
    end
  end

  describe "view all images link" do
    test "doesn't display if there are 12 or fewer images", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/اب-كوئى-جنگ-نه-هوگى/item/3")

      response = render(view)
      refute response =~ "View all images"
    end

    test "links to viewer if there are more than 12 images", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      assert view
             |> has_element?(
               "a[href='/i/învăţămîntul-trebuie-urmărească-dez/item/1/viewer/1']",
               "View all images"
             )
    end
  end

  describe "similar button" do
    test "jumps to the similar items section", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      assert view
             |> has_element?(
               "a[href='#similar-items']",
               "Similar"
             )

      assert view
             |> has_element?("#similar-items")
    end
  end

  describe "size toggle" do
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
  end

  describe "related items" do
    test "shows some related items, but no collections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      assert view |> has_element?("#related-same-project a", "Similar Item Same Project")

      assert view
             |> has_element?("#related-different-project a", "Similar Item Different Project")

      assert view
             |> has_element?("#related-different-project .btn-transparent")
    end

    test "doesn't show collection related items for items without a collection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/زلزلہ/item/2")

      refute view |> has_element?("#related-same-project")
    end
  end

  describe ".rights_path" do
    test "converts strings to image paths" do
      assert ItemLive.rights_path("Copyright Not Evaluated") == "copyright-not-evaluated.svg"
      assert ItemLive.rights_path("CC-BY 4.0") == "ccby-40.svg"
      assert ItemLive.rights_path(["CC-BY 4.0"]) == "ccby-40.svg"

      assert ItemLive.rights_path("In Copyright - Rights-holder(s) Unlocatable or Unidentifiable") ==
               "in-copyright--rightsholders-unlocatable-or-unidentifiable.svg"

      assert ItemLive.rights_path("In Copyright - Educational Use Permitted") ==
               "in-copyright--educational-use-permitted.svg"
    end
  end

  describe "project display and navigation" do
    test "creates a link to a project page when one is published", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/i/învăţămîntul-trebuie-urmărească-dez/item/1")

      assert view
             |> element("a.filter-link", "Test Project")
             |> render() =~ "/collections/project"
    end

    test "creates a filter link to the project not published", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, "/i/similar-item-different-project/item/similar-to-1-diff-project")

      assert view
             |> element("a.filter-link", "Different Project")
             |> render() =~ "/search"
    end
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
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "زلزلہ - Digital Collections"

    {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2/metadata")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "Metadata - زلزلہ - Digital Collections"

    {:ok, _view, html} = live(conn, "/i/زلزلہ/item/2/viewer/0")

    title =
      html
      |> Floki.parse_document!()
      |> Floki.find("title")
      |> Floki.text()
      |> String.trim_leading()
      |> String.trim_trailing()

    assert title == "Viewer - زلزلہ - Digital Collections"
  end

  describe "user sets" do
    test "item can be saved to a user set", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Save")
      |> render_click()

      # Create new set
      assert view
             |> element("button", "Create new set")
             |> render_click() =~ "Set name"
    end
  end

  describe "correction form" do
    test "correction link opens form in modal", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Correct")
      |> render_click()

      assert view
      |> form("#correction-form", name: "me", email: "me@example.com", message: "it is wrong")
      |> render_submit() =~ "Thank you for submitting a message through the Suggest a Correction form"
    end
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
