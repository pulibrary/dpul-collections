defmodule DpulCollectionsWeb.LoginTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  import DpulCollections.AccountsFixtures

  # This makes sure that the SQL sandbox works with LiveView by navigating
  # through multiple pages in the same live_session.
  test "the user login flow works", %{conn: conn} do
    user = user_fixture()

    conn
    |> visit("/")
    |> click_link("Log in")
    |> fill_in("Email", with: user.email)
    |> click_button("Log in with email")
    |> visit("/users/log-in/#{generate_user_magic_link_token(user) |> elem(0)}")
    |> click_button("Keep me logged in on this device")
    |> assert_has("a", text: "Log out")
  end

  # This makes sure that the sandbox plug works.
  test "feature tests can login", %{conn: conn} do
    user = user_fixture()

    conn
    |> FiggyTestSupport.feature_login(user)
    |> visit("/")
    |> assert_has("a", text: "Log out")
  end
end
