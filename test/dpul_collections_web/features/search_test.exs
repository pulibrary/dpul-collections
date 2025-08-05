defmodule DpulCollectionsWeb.Features.SearchTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "image counts are shown when total files outnumber visible images", %{conn: conn} do
    conn
    |> visit("/search?q=")
    # when filecount exceeds visible images show image total
    |> assert_has("#item-1", text: "Document-1")
    # when visible images equals filecount don't show image total
    |> assert_has("#filecount-1", text: "7 Images")
  end
end
