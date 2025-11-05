defmodule DpulCollectionsWeb.UserSetsLiveTest do
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

  describe "GET /sets" do
    test "connects when user is logged in", %{conn: conn} do
      conn =
        conn
        |> log_in_user(user_fixture())
        |> get(~p"/sets")

      assert html_response(conn, 200) =~ "My Sets"
    end

    test "redirects when user is not logged in", %{conn: conn} do
      conn = get(conn, ~p"/sets")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must log in"
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "shows only the logged-in user's sets", %{conn: conn} do
      me = user_fixture()
      not_me = user_fixture()

      mine = set_fixture(user_scope_fixture(me), title: "Set I made", description: "cool")
      # put an item in it
      set_item_fixture(%{solr_id: "1"}, user_scope_fixture(me), mine)

      _not_mine =
        set_fixture(user_scope_fixture(not_me),
          title: "Someone else's set",
          description: "boring"
        )

      {:ok, _view, html} =
        conn
        |> log_in_user(me)
        |> live(~p"/sets")

      # shows the user's sets
      # does not show another user's sets

      assert html =~ "Set I made"
      assert html =~ "cool"
      refute html =~ "Someone else's set"
      refute html =~ "boring"
    end

    test "renders when the user has no sets", %{conn: conn} do
      me = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_user(me)
        |> live(~p"/sets")

      assert html =~ "My Sets"
    end

    test "renders when a set is empty", %{conn: conn} do
      me = user_fixture()
      _mine = set_fixture(user_scope_fixture(me), title: "Set I made", description: "cool")

      {:ok, _view, html} =
        conn
        |> log_in_user(me)
        |> live(~p"/sets")

      assert html =~ "Set I made"
      assert html =~ "cool"
    end

    test "allows set deletion" do
    end

    test "links to the set page" do
    end
  end
end
