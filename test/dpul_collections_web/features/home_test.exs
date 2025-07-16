defmodule DpulCollectionsWeb.Features.HomeTest do
  use ExUnit.Case
  use PhoenixTest.Playwright.Case
  import SolrTestSupport
  alias DpulCollections.Solr

  setup do
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "home page is accessible", %{conn: conn} do
    Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
    Solr.commit(active_collection())

    conn
    |> visit("/")
    |> unwrap(&TestUtils.assert_a11y/1)
  end
end
