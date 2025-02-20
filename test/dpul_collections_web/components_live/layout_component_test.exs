defmodule DpulCollectionsWeb.LayoutComponentTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  import LiveIsolatedComponent
  @endpoint DpulCollectionsWeb.Endpoint


  test "LayoutComponent" do
    assert render_component(DpulCollectionsWeb.LayoutComponent, id: 123) =~
         "<header"
  end

  test "has a dropdown menu for language preference" do
    assert render_component(DpulCollectionsWeb.LayoutComponent, id: 123) =~
         "<button id=\"dropdownButton\""
  end

  # The test below returns the following error: 
  # -- no push or navigation command found within JS commands: [["toggle",{"to":"#dropdownMenu"}]]
  # The test environment does not execute frontend JS behaviors, 
  # so the way to test this is to modify the component to use 
  # phx-click with LiveView state changes (assigns) that can be tested

  test "clicking the button toggles dropdown visibility" do
    {:ok, view, _html} = live_isolated_component(DpulCollectionsWeb.LayoutComponent)

    assert has_element?(view, "#dropdownMenu[aria-hidden='true']")

    view |> element("#dropdownButton") |> render_click()

    assert has_element?(view, "#dropdownMenu[aria-hidden='false']")

    view |> element("#dropdownButton") |> render_click()

    assert has_element?(view, "#dropdownMenu[aria-hidden='true']")
  end

end
