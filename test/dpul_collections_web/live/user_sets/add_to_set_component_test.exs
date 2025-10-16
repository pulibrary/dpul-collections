defmodule DpulCollectionsWeb.UserSets.AddToSetsComponentTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Solr

  describe "render" do
    setup do
      original_config = Application.fetch_env!(:dpul_collections, :feature_account_toolbar)
      Application.put_env(:dpul_collections, :feature_account_toolbar, false)

      on_exit(fn ->
        Application.put_env(:dpul_collections, :feature_account_toolbar, original_config)
      end)
    end

    test "doesn't render when users aren't enabled (prod)", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(1), active_collection())
      Solr.soft_commit(active_collection())

      {:ok, view, html} =
        conn
        |> log_in_user(user_fixture())
        |> live("/browse?r=0")

      refute html =~ "Save to Set"
      refute view |> has_element?("button", "Save")
    end
  end

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
