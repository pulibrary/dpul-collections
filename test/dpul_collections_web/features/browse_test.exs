defmodule DpulCollectionsWeb.Features.BrowseViewTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(20), active_collection())
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

    test "clicking the pinned items marker switches tabs", %{conn: conn} do
      conn
      |> visit("/browse")
      |> assert_has(".tab-content #browse-item-1")
      |> scroll_down()
      |> click("#sticky-tools #liked-button .bg-accent", "")
      |> assert_has("h2", text: "Liked items")
    end
  end

  def scroll_down(conn) do
    conn
    |> unwrap(&Frame.evaluate(&1.frame_id, "window.scrollTo(0, document.body.scrollHeight);"))
  end
end
