defmodule DpulCollectionsWeb.SearchBarComponentTest do
  use DpulCollectionsWeb.ConnCase, async: true
  alias DpulCollectionsWeb.SearchBarComponent

  describe "search_label/1" do
    test "returns 'Search' when collection title is empty" do
      assert SearchBarComponent.search_label("") == "Search"
    end

    test "returns 'Search all' when a collection title is provided" do
      assert SearchBarComponent.search_label("Omega Project") == "Search all"
    end
  end
end