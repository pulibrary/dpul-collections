defmodule DpulCollectionsWeb.BrowseTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias PhoenixTest.Playwright.Frame
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(20), active_collection())
    Solr.soft_commit(active_collection())
    {:ok, %{}}
  end

  test "browse page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.soft_commit(active_collection())

    conn
    |> visit("/browse?r=0")
    |> unwrap(&TestUtils.assert_a11y/1)
  end

  def scroll_down(conn) do
    conn
    |> unwrap(&Frame.evaluate(&1.frame_id, "window.scrollTo(0, document.body.scrollHeight);"))
  end
end
