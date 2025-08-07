defmodule DpulCollectionsWeb.ItemLiveMetadataTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import SolrTestSupport
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup_all do
    Solr.add(
      [
        %{
          id: 1,
          description_txtm: ["A series of paintings of wizards"],
          title_txtm: ["Gandalf the Grey"],
          transliterated_title_txtm: ["Gandalf the Gray"],
          alternative_title_txtm: ["Gandalf the White"],
          sort_title_txtm: ["gandalf the grey"],
          creator_txt_sort: ["Bifur"],
          contributor_txt_sort: ["Bofur", "Bombur"],
          publisher_txt_sort: ["Elrond"],
          language_txt_sort: ["Common", "Elvish"],
          display_date_s: "Durin",
          genre_txt_sort: ["Paintings"],
          content_warning_s: "Some people may not want to see this",
          series_txt_sort: ["Lord of the Rings"],
          provenance_txtm: ["Donation of Bilbo Baggins"],
          rights_statement_txtm: ["Copyright"],
          subject_txt_sort: ["Magic"],
          geo_subject_txt_sort: ["Mordor"],
          keywords_txt_sort: ["wands", "hats"],
          geographic_origin_txt_sort: ["Mountains"],
          height_txtm: ["40"],
          width_txtm: ["20"],
          page_count_txtm: ["27"],
          file_count_i: 30,
          ephemera_project_title_s: "Things",
          box_number_txtm: ["65"],
          folder_number_txtm: ["18"],
          barcode_txtm: ["3334445556"],
          holding_location_txt_sort: ["Special Collections"],
          iiif_manifest_url_s:
            "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest",
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

  test "/item/{:id}/metadata displays all the metadata fields and has links for linkable fields",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "/i/gandalf-the-grey/item/1/metadata")

    assert view |> has_element?("h1", "Metadata")
    assert view |> has_element?("h2", "Item Description")
    assert view |> has_element?("p", "A series of paintings of wizards")
    assert view |> has_element?("h2", "Descriptive Information")
    assert view |> has_element?("dt", "Title")
    assert view |> has_element?("dd", "Gandalf the Grey")
    assert view |> has_element?("dt", "Transliterated Title")
    assert view |> has_element?("dd", "Gandalf the Gray")
    assert view |> has_element?("dt", "Alternative Title")
    assert view |> has_element?("dd", "Gandalf the White")
    assert view |> has_element?("dt", "Sort Title")
    assert view |> has_element?("dd", "gandalf the grey")
    assert view |> has_element?("dt", "Creator of work")
    assert view |> has_element?("dd", "Bifur")
    assert view |> has_element?("a[href='/search?filter[creator]=Bifur']")
    assert view |> has_element?("dt", "Contributor")
    assert view |> has_element?("a[href='/search?filter[contributor]=Bombur']")
    assert view |> has_element?("dd", "Bofur")
    assert view |> has_element?("dd", "Bombur")
    assert view |> has_element?("dt", "Publisher")
    assert view |> has_element?("dd", "Elrond")
    assert view |> has_element?("a[href='/search?filter[publisher]=Elrond']")
    assert view |> has_element?("dt", "Language")
    assert view |> has_element?("dd", "Common")
    assert view |> has_element?("a[href='/search?filter[language]=Common']")
    assert view |> has_element?("dd", "Elvish")
    assert view |> has_element?("dt", "Date Created")
    assert view |> has_element?("dd", "Durin")
    assert view |> has_element?("a[href='/search?filter[date]=Durin']")
    assert view |> has_element?("dt", "Genre")
    assert view |> has_element?("dd", "Paintings")
    assert view |> has_element?("a[href='/search?filter[genre]=Paintings']")
    assert view |> has_element?("dt", "Content Warning")
    assert view |> has_element?("dd", "Some people may not want to see this")
    assert view |> has_element?("dt", "Series")
    assert view |> has_element?("dd", "Lord of the Rings")
    assert view |> has_element?("dt", "Provenance")
    assert view |> has_element?("dd", "Donation of Bilbo Baggins")
    assert view |> has_element?("dt", "Rights Statement")
    assert view |> has_element?("dd", "Copyright")
    assert view |> has_element?("a[href='/search?filter[rights_statement]=Copyright']")
    assert view |> has_element?("dt", "Subject")
    assert view |> has_element?("dd", "Magic")
    assert view |> has_element?("a[href='/search?filter[subject]=Magic']")
    assert view |> has_element?("dt", "Geographic Subject")
    assert view |> has_element?("dd", "Mordor")
    assert view |> has_element?("a[href='/search?filter[geo_subject]=Mordor']")
    assert view |> has_element?("dt", "Keywords")
    assert view |> has_element?("dd", "wands")
    assert view |> has_element?("dd", "hats")
    assert view |> has_element?("dt", "Geographic Origin")
    assert view |> has_element?("dd", "Mountains")
    assert view |> has_element?("a[href='/search?filter[geographic_origin]=Mountains']")
    assert view |> has_element?("dt", "Height")
    # TODO: make it display cm
    assert view |> has_element?("dd", "40")
    assert view |> has_element?("dt", "Width")
    assert view |> has_element?("dd", "20")
    assert view |> has_element?("dt", "Page Count")
    assert view |> has_element?("dd", "27")
    assert view |> has_element?("dt", "File Count")
    assert view |> has_element?("dd", "30")
    assert view |> has_element?("dt", "Ephemera Project")
    assert view |> has_element?("dd", "Things")
    assert view |> has_element?("a[href='/search?filter[project]=Things']")
    assert view |> has_element?("dt", "Box number")
    assert view |> has_element?("dd", "65")
    assert view |> has_element?("dt", "Folder number")
    assert view |> has_element?("dd", "18")
    assert view |> has_element?("dt", "Barcode")
    assert view |> has_element?("dd", "3334445556")
    assert view |> has_element?("dt", "Holding location")
    assert view |> has_element?("dd", "Special Collections")
    assert view |> has_element?("dt", "IIIF Manifest URL")

    assert view
           |> has_element?(
             "dd",
             "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest"
           )

    # Does not display unconfigured fields
    assert !(view |> has_element?("dd", "https://example.com/iiif/2/image1"))
  end

  test "/item/{:id}/metadata redirects when slug is missing", %{conn: conn} do
    conn = get(conn, "/item/1/metadata")
    assert redirected_to(conn, 302) == "/i/gandalf-the-grey/item/1/metadata"
  end

  test "/i/{:slug}/item/{:id}/metadata redirects when slug is incorrect",
       %{conn: conn} do
    conn = get(conn, "/i/not-a-real-slug/item/1/metadata")
    assert redirected_to(conn, 302) == "/i/gandalf-the-grey/item/1/metadata"
  end

  test "/i/{:slug}/item/{:id}/metadata does not redirect when slug is correct",
       %{conn: conn} do
    conn = get(conn, "/i/gandalf-the-grey/item/1/metadata")
    assert conn.status == 200
  end

  test "/i/{:slug}/item/{:id}/metadata 404s with a bad id", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/i/not-a-real-slug/item/badid1/metadata")
    end
  end

  test "GET /item/{:id}/metadata 404s with a bad id", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/item/badid1/metadata")
    end
  end
end
