defmodule DpulCollectionsWeb.UserSetsLive.ShowTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  import DpulCollections.UserSetsFixtures
  import DpulCollections.AccountsFixtures
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.soft_commit(active_collection())
    :ok
  end

  describe "GET /sets/:id when not logged in" do
    test "displays that user set without any text", %{conn: conn} do
      set = set_fixture(user_scope_fixture())
      item_1 = set_item_fixture(%{solr_id: "1"}, nil, set)
      item_2 = set_item_fixture(%{solr_id: "2"}, nil, set)

      {:ok, view, html} =
        conn
        |> live(~p"/sets/#{set.id}")

      assert html =~ "Item Set"
      assert html =~ "2 Items"

      assert view
             |> element("li#browse-item-#{item_1.solr_id}")
             |> has_element?

      assert view
             |> element("li#browse-item-#{item_2.solr_id}")
             |> has_element?
    end
  end
end
