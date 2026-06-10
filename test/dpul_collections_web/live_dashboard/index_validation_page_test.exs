defmodule DpulCollectionsWeb.LiveDashboard.IndexValidationPageTest do
  alias DpulCollections.Solr
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    [
      # sae project
      "f99af4de-fed4-4baa-82b1-6e857b230306",
      "e8abfa75-253f-428a-b3df-0e83ff2b20f9",
      "e379b822-27cc-4d0e-bca7-6096ac38f1e6"
    ]
    |> Enum.each(&FiggyTestSupport.index_record_id_directly/1)

    # Add an extra item
    Solr.add([
      %{
        "id" => "extra-item",
        "title_txtm" => ["test title 1"],
        "collection_titles_ss" => ["South Asian Ephemera"]
      }
    ])

    Solr.soft_commit(active_collection())

    on_exit(fn -> Solr.delete_all(active_collection()) end)
    :ok
  end

  describe "GET /dev/dashboard/index_validation" do
    test "it shows a collection and the number of items that are indexed in it", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> put_req_header("authorization", "Basic " <> Base.encode64("admin:test"))
        |> live(~p"/dev/dashboard/index_validation")

      # There's the count in DC's Solr
      assert view
             |> has_element?(".row", ~r(South Asian Ephemera.*Digital Collections Count.*3))

      # There's a list of missing items.
      assert view
             |> has_element?(
               "a[href='https://figgy.princeton.edu/catalog/d82efa97-c69b-424c-83c2-c461baae8307']",
               "d82efa97-c69b-424c-83c2-c461baae8307"
             )

      # There's a list of extra items

      # TODO: Add Figgy Count, Extra Count, Missing Count
    end
  end
end
