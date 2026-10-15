defmodule DpulCollectionsWeb.SearchComponentsTest do
  use DpulCollectionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import DpulCollectionsWeb.SearchComponents

  test "renders standard 'Search' text when collection_title is empty" do
    # Test the functional component in isolation
    html = render_component(&search_bar/1, collection_title: "")

    assert html =~ "Search"
    refute html =~ "Search all"
  end

  test "renders 'Search all' text when collection_title is populated" do
    html = render_component(&search_bar/1, collection_title: "Omega Project")

    assert html =~ "Search all"
    assert html =~ "In this Collection"
  end
end
