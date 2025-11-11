defmodule DpulCollectionsWeb.LoginTest do
  alias DpulCollections.Accounts
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  import DpulCollections.AccountsFixtures

  # This makes sure that the SQL sandbox works with LiveView by navigating
  # through multiple pages in the same live_session.
  test "the user login flow works", %{conn: conn} do
    user = user_fixture()

    conn
    |> visit("/")
    |> click_button("My Account")
    |> click_link("Log in")
    |> fill_in("Email", with: user.email)
    |> click_button("Log in with email")
    |> visit("/users/log-in/#{generate_user_magic_link_token(user) |> elem(0)}")
    |> click_button("Keep me logged in on this device")
    |> click_button("My Account")
    |> assert_has("a", text: "Log out")
    |> assert_has("a", text: "Settings")
    |> assert_has("a", text: "My Sets")
  end

  test "auto-registration via login & confirmation works", %{conn: conn} do
    out =
      conn
      |> visit("/")
      |> click_button("My Account")
      |> click_link("Log in")
      |> fill_in("Email", with: "test@example.com")
      |> click_button("Log in with email")
      |> assert_has("*", text: "You will receive instructions for logging in shortly.")

    user = Accounts.get_user_by_email("test@example.com")

    out
    |> visit("/users/log-in/#{generate_user_magic_link_token(user) |> elem(0)}")
    |> click_button("Confirm and stay logged in")
    |> click_button("My Account")
    |> assert_has("a", text: "Log out")
  end

  # This makes sure that the sandbox plug works.
  test "feature tests can login", %{conn: conn} do
    user = user_fixture()

    conn
    |> FiggyTestSupport.feature_login(user)
    |> visit("/")
    |> click_button("My Account")
    |> assert_has("a", text: "Log out")
  end
end
