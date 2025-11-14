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
    test "users can add an item to a user set if not logged in", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(2), active_collection())
      Solr.soft_commit(active_collection())
      user = user_fixture()

      conn =
        conn
        |> visit("/browse?r=0")
        |> click_button(".browse-item:first-child a", "Save")
        |> fill_in("Email", with: user.email)
        |> click_button("Log in with email")
        |> assert_has("h1", text: "We emailed you a code")

      last_email = Swoosh.Adapters.Local.Storage.Memory.pop()

      [_full_link, path] =
        ~r/http:\/\/.*?(\/.*)/
        |> Regex.run(last_email.text_body)

      conn
      |> visit(path)
      |> assert_has("h1", text: "Welcome")
      |> click_button("Log me in only this time")
      # Now we should be back at browse
      |> assert_has("h1", text: "Browse")
      # See if the item popped up to be added.
      |> assert_has("h2", text: "Save to Set")
    end

    test "users can add an item to a user set", %{conn: conn} do
      Solr.add(SolrTestSupport.mock_solr_documents(2), active_collection())
      Solr.soft_commit(active_collection())
      user = user_fixture()

      conn
      |> FiggyTestSupport.feature_login(user)
      |> visit("/browse?r=0")
      |> click_button(".browse-item:first-child a", "Save")
      |> assert_has("h2", text: "Save to Set")
      |> click_button("Create new set")
      # Can't submit empty form.
      |> click_button("Create Set")
      |> fill_in("Set name", with: "My Awesome Set")
      |> fill_in("Set description", with: "My awesome set description")
      # Can make a new set that has it.
      |> click_button("Create Set")
      |> assert_has("li", text: "My Awesome Set - 1 Item")
      |> assert_has("li.has-item", text: "My Awesome Set - 1 Item")
      # Can make a new set, then cancel
      |> click_button("Create new set")
      |> click_button("Cancel")
      # A new one didn't get made.
      |> assert_has("#add-set-modal li", count: 1)
      |> click_button("Close modal")
      |> assert_path("/browse", query_params: %{"r" => 0})
      # I can add a second item to that set.
      |> click_button(".browse-item:nth-child(2) a", "Save")
      |> assert_has("li", text: "My Awesome Set - 1 Item")
      |> refute_has("li.has-item")
      |> click_button("My Awesome Set - 1 Item")
      |> assert_has("li.has-item")
      # I can remove it from a set.
      |> click_button("My Awesome Set - 2 Items")
      # We might want a confirmation here, but it's not in the mockups.
      |> refute_has("li.has-item")
      |> assert_has("li", text: "My Awesome Set - 1 Item")
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
