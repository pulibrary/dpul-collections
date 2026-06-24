defmodule DpulCollectionsWeb.ItemLiveSyncTest do
  # Some of the tests here mock Req, so have to be run synchronously.
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  import Mock
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
          category_subjects_txt:
            "{\"Minorities, ethnic and racial groups\":[\"Ethnic relations\"],\"Politics and government\":[\"Peace movements\",\"Peace negotiations\"],\"Religion\":[\"Liberation theology\"]}",
          content_warning_s: "content warning",
          contributor_txt_sort: ["contributor"],
          creator_txt_sort: ["creator"],
          summary_txtm: ["This is a test description"],
          display_date_s: "2022",
          file_count_i: 17,
          folder_number_txtm: ["1"],
          format_txt_sort: ["format"],
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
          collection_titles_ss: ["Test Project", "Second Project"],
          collection_ids_ss: ["similar-to-1-is-a-project", "similar-to-1-is-a-second-project"],
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
          title_txtm: "Similar Item Same Collection",
          file_count_i: 1,
          collection_titles_ss: "Test Project",
          format_txt_sort: ["format"],
          subject_txt_sort: ["subject"],
          width_txtm: ["10"],
          height_txtm: ["20"],
          summary_txtm:
            "This is a really really really long description that has a bunch of information which is too much for a bluesky tweet and so probably we should truncate it. I'm going to keep on rambling here, so that my stream of consciousness is caught in this test."
        },
        %{
          id: "similar-to-1-diff-project",
          file_count_i: 1,
          title_txtm: "Similar Item Different Collection",
          collection_titles_ss: "Different Project",
          format_txt_sort: ["format"],
          subject_txt_sort: ["subject"]
        },
        %{
          id: "similar-to-1-is-a-project",
          title_txtm: "Test Project",
          tagline_txtm: "This is a tagline.",
          summary_txtm: ["This is a test description"],
          authoritative_slug_s: "project",
          resource_type_s: "collection"
        },
        %{
          id: "similar-to-1-is-a-second-project",
          title_txtm: "Second Project",
          tagline_txtm: "Second tagline.",
          summary_txtm: ["Second description"],
          authoritative_slug_s: "second-project",
          resource_type_s: "collection"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())
    :ok
  end

  describe "correction form" do
    test "correction link opens form in modal", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Correct")
      |> render_click()

      assert view
             |> has_element?("p", "Please use this area to report")

      with_mock(DpulCollections.LibanswersApi,
        create_ticket: fn _params ->
          {:ok,
           %{
             "isShared" => false,
             "ticketUrl" => "http://mylibrary.libanswers.com/admin/ticket?qid=12345",
             "claimed" => 0
           }}
        end
      ) do
        html =
          view
          |> form("#correction-form",
            name: "me",
            email: "me@example.com",
            message: "a correction"
          )
          |> render_submit()

        assert html =~ "Thank you for your suggestion"

        assert_called(
          DpulCollections.LibanswersApi.create_ticket(%{
            "name" => "me",
            "email" => "me@example.com",
            "message" => "a correction",
            "item_id" => "2"
          })
        )
      end
    end

    test "form does not have all required values", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Correct")
      |> render_click()

      with_mock(DpulCollections.LibanswersApi,
        create_ticket: fn _params -> nil end
      ) do
        html =
          view
          |> form("#correction-form",
            name: "me",
            email: "me@example.com"
          )
          |> render_submit()

        assert html =~ "Sorry, something went wrong"

        assert_not_called(DpulCollections.LibanswersApi.create_ticket(:_))

        # You can open it again
        view
        |> element(".metadata button", "Correct")
        |> render_click()

        assert view
               |> has_element?("dialog#correction-form-modal")

        assert view
               |> has_element?("p", "Please use this area to report")
      end
    end

    test "the form's honeypot field is populated", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Correct")
      |> render_click()

      with_mock(DpulCollections.LibanswersApi,
        create_ticket: fn _params -> nil end
      ) do
        html =
          view
          |> form("#correction-form",
            name: "me",
            email: "me@example.com",
            message: "a correction",
            feedback: "this should be empty"
          )
          |> render_submit()

        assert html =~ "Sorry, something went wrong"

        assert_not_called(DpulCollections.LibanswersApi.create_ticket(:_))

        # You can open it again
        view
        |> element(".metadata button", "Correct")
        |> render_click()

        assert view
               |> has_element?("dialog#correction-form-modal")

        assert view
               |> has_element?("p", "Please use this area to report")
      end
    end

    test "api failure gives appropriate message to user", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> live(~p"/i/زلزلہ/item/2")

      # Open dialog
      view
      |> element(".metadata button", "Correct")
      |> render_click()

      with_mock(Req,
        post: fn
          "https://faq.library.princeton.edu/api/1.1/oauth/token", _ ->
            LibanswersApiFixtures.oauth_response()

          "https://faq.library.princeton.edu/api/1.1/ticket/create", _ ->
            LibanswersApiFixtures.ticket_create_400()
        end
      ) do
        html =
          view
          |> form("#correction-form",
            name: "me",
            email: "me@example.com",
            message: "a correction"
          )
          |> render_submit()

        assert html =~ "Sorry, something went wrong"
      end
    end
  end

end
