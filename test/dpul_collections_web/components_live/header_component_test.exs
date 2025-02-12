defmodule DpulCollectionsWeb.HeaderComponentTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  @endpoint DpulCollectionsWeb.Endpoint


  test "HeaderComponent" do
    assert render_component(DpulCollectionsWeb.HeaderComponent, id: 123) =~
         "<header>"
  end

end
