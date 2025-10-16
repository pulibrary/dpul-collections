defmodule DpulCollectionsWeb.BrowseTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  alias DpulCollections.Solr
  import DpulCollections.AccountsFixtures

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(20), active_collection())
    Solr.soft_commit(active_collection())
    {:ok, %{}}
  end

  describe "user sets" do
    test "users can add an item to a user set", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(1), active_collection())
      Solr.soft_commit(active_collection())
      user = user_fixture()

      conn
      |> FiggyTestSupport.feature_login(user)
      |> visit("/browse?r=0")
      |> click_button(".browse-item:first-child button", "Save")
      |> assert_has("h2", text: "Save to Set")
      |> click_button("Create new set")
      |> fill_in("Set name", with: "My Awesome Set")
      |> fill_in("Set description", with: "My awesome set description")
      |> click_button("Create Set")
      |> assert_has("li", text: "My Awesome Set - 1 Item")
      |> assert_has("li.has-item", text: "My Awesome Set - 1 Item")
    end
  end

  test "browse page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/browse?r=0")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  def scroll_down(conn) do
    conn
    |> unwrap(&Frame.evaluate(&1.frame_id, "window.scrollTo(0, document.body.scrollHeight);"))
  end
end
