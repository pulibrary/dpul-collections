defmodule DpulCollectionsWeb.Features.IndexingTest do
  use DpulCollections.DataCase
  use PhoenixTest.Playwright.Case
  alias DpulCollections.Solr

  test "filtering to publisher works when there are quotation marks in the value", %{conn: conn} do
    id = "ca9184a3-357d-42f1-b602-d708e278a110"
    FiggyTestSupport.index_record_id_directly(id)
    Solr.soft_commit()

    conn
    |> visit("/i/серафима-ильинична-гопнер-18801966/item/ca9184a3-357d-42f1-b602-d708e278a110")
    |> assert_has(".phx-connected")
    |> click_link("Издательство")
    |> assert_path("/search")
    |> assert_has("li.item")
  end
end
