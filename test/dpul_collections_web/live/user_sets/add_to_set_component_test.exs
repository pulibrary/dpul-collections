defmodule DpulCollectionsWeb.UserSets.AddToSetsComponentTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Solr

  describe "append_item" do
    test "doesn't append if not given valid data", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(1), active_collection())
      Solr.soft_commit(active_collection())

      {:ok, view, _html} =
        conn
        |> log_in_user(user_fixture())
        |> live("/browse?r=0")

      # Open dialog
      view
      |> element("button", "Save")
      |> render_click()

      # Create new set
      view
      |> element("button", "Create new set")
      |> render_click()

      assert view
             |> element("#add-set-modal form")
             |> render_submit() =~ "Set name"
    end
  end
end
