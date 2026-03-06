defmodule DpulCollectionsWeb.RawDocumentControllerTest do
  use DpulCollectionsWeb.ConnCase
  alias DpulCollections.Solr

  setup do
    Solr.add([
      %{
        id: "27fd4d29-1170-47a5-891b-f2743873bcef",
        title_txtm: ["Test Item"],
        display_date_s: "2024"
      },
      %{
        id: "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
        title_txtm: ["Test Collection"],
        authoritative_slug_s: "islamicmss"
      }
    ])

    Solr.soft_commit(active_collection())
    :ok
  end

  describe "item/2" do
    test "returns a Solr JSON document", %{conn: conn} do
      conn = get(conn, ~p"/item/27fd4d29-1170-47a5-891b-f2743873bcef/raw")
      response = json_response(conn, 200)
      assert response["id"] == "27fd4d29-1170-47a5-891b-f2743873bcef"
      assert is_list(response["title_txtm"])
    end

    test "returns a 404 error when the item is not found", %{conn: conn} do
      conn = get(conn, ~p"/item/invalid-id/raw")
      assert json_response(conn, 404) == %{"error" => "Item not found"}
    end
  end

  describe "collection/2" do
    test "returns a Solr JSON document", %{conn: conn} do
      conn = get(conn, ~p"/collections/islamicmss/raw")
      response = json_response(conn, 200)
      assert response["authoritative_slug_s"] == "islamicmss"
      assert is_list(response["title_txtm"])
    end

    test "returns a 404 error when the collection is not found", %{conn: conn} do
      conn = get(conn, ~p"/collections/invalid-id/raw")
      assert json_response(conn, 404) == %{"error" => "Collection not found"}
    end
  end
end
