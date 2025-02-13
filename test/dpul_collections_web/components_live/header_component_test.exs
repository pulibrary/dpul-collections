defmodule DpulCollectionsWeb.HeaderComponentTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint


  test "HeaderComponent" do
    assert render_component(DpulCollectionsWeb.HeaderComponent, id: 123) =~
         "<header"
  end

  test "has a dropdown menu for language preference" do
    assert render_component(DpulCollectionsWeb.HeaderComponent, id: 123) =~
         "<button id=\"dropdownButton\""
  end

  # The test below returns the following error: 
  # -- no push or navigation command found within JS commands: [["toggle",{"to":"#dropdownMenu"}]]
  # The test environment does not execute frontend JS behaviors, 
  # so the way to test this is to modify the component to use 
  # phx-click with LiveView state changes (assigns) that can be tested

  # test "clicking the button toggles dropdown visibility", %{conn: conn} do
  #   {:ok, view, _html} = live(conn, ~p"/")

  #   assert has_element?(view, "#dropdownMenu[aria-hidden='true']")

  #   view |> element("#dropdownButton") |> render_click()

  #   assert has_element?(view, "#dropdownMenu[aria-hidden='false']")

  #   view |> element("#dropdownButton") |> render_click()

  #   assert has_element?(view, "#dropdownMenu[aria-hidden='true']")
  # end

end
