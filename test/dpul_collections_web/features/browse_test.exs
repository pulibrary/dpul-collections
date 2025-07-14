defmodule DpulCollectionsWeb.Features.BrowseViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
    {:ok, %{}}
  end

  describe "tab interface" do
    test "clicking a tab switches to that content", %{conn: conn} do
      conn
      |> visit("/browse")
      |> assert_has(".tab-content #browse-item-1")
      # No header until it's displayed.
      |> refute_has("h2", text: "Liked items")
      |> click("*[role='tab']", "My Liked Items (0)")
      |> assert_has("h2", text: "Liked items")
      |> click("*[role='tab']", "Recommended Items")
      |> assert_has("h2", text: "Recommendations")
    end
  end
end
