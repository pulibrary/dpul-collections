defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntryTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
  alias DpulCollections.IndexingPipeline

  describe "to_solr_document/1" do
    test "includes descriptions if found" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      assert doc1[:description_txtm] == ["Asra-Panahi", "Berlin-Protest", "Elnaz-Rekabi"]
      assert doc2[:description_txtm] == []
      assert doc3[:description_txtm] == nil
    end

    test "indexes page_count_i" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, _doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      assert doc1[:page_count_i] == 27
      assert doc2[:page_count_i] == 0
    end

    test "includes date range if found, date if not" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      # Add one to exercise the "approximate" scenario
      {:ok, entry4} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 4"],
              "date_range" => [
                %{
                  "approximate" => "1",
                  "created_at" => nil,
                  "end" => ["2013"],
                  "id" => nil,
                  "internal_resource" => "DateRange",
                  "new_record" => true,
                  "start" => ["2011"],
                  "updated_at" => nil
                }
              ]
            }
          }
        })

      # Add one to exercise empty date_created
      {:ok, entry5} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 5"],
              "date_created" => []
            }
          }
        })

      doc4 = HydrationCacheEntry.to_solr_document(entry4)
      doc5 = HydrationCacheEntry.to_solr_document(entry5)

      assert doc1[:years_is] == [2022]
      assert doc2[:years_is] == [1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005]
      assert doc3[:years_is] == nil
      assert doc4[:years_is] == [2011, 2012, 2013]
      assert doc5[:years_is] == nil

      assert doc1[:display_date_s] == "2022"
      assert doc2[:display_date_s] == "1995 - 2005"
      assert doc3[:display_date_s] == nil
      assert doc4[:display_date_s] == "2011 - 2013 (approximate)"
      assert doc5[:display_date_s] == nil
    end
  end
end
