defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntryTest do
  use DpulCollections.DataCase
  import ExUnit.CaptureLog
  require Logger

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

    test "transforms related member image service urls" do
      # Add FileMetadata with both a JP2/Pyramidal derivative, to ensure it
      # picks the pyramidal
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "member_ids" => %{
              "1" => %{
                "internal_resource" => "FileSet",
                "id" => "9ad621a7b-01ea-4895-9c3d-a8c6eaab4013",
                "metadata" => %{
                  "file_metadata" => [
                    # Not this one - it's an old JP2
                    %{
                      "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4014"},
                      "internal_resource" => "FileMetadata",
                      "mime_type" => ["image/jp2"],
                      "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
                    },
                    %{
                      "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4017"},
                      "internal_resource" => "FileMetadata",
                      "mime_type" => ["image/tiff"],
                      "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
                    }
                  ]
                }
              }
            }
          },
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "member_ids" => [%{"id" => "1"}],
              "title" => ["test title 4"]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      # This is the pyramidal derivative.
      assert doc[:image_service_urls_ss] == [
               "https://iiif-cloud.princeton.edu/iiif/2/0c%2Fff%2F89%2F0cff895a01ea48959c3da8c6eaab4017%2Fintermediate_file"
             ]
    end

    test "can handle when members do not have the correct file metadata type" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "member_ids" => %{
              "1" => %{
                "internal_resource" => "FileSet",
                "id" => "9ad621a7b-01ea-4895-9c3d-a8c6eaab4013",
                "metadata" => %{
                  "file_metadata" => [
                    # PDF member
                    %{
                      "id" => %{"id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4017"},
                      "internal_resource" => "FileMetadata",
                      "mime_type" => ["application/pdf"],
                      "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
                    }
                  ]
                }
              }
            }
          },
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "member_ids" => [%{"id" => "1"}],
              "title" => ["test title 4"]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      assert doc[:image_service_urls_ss] == []
    end

    test "includes date range if found, date if not" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      # date marked "approximate"
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

      # empty date_created
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

      # Add one to exercise date_created with format `.*yyyy`
      {:ok, entry6} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 6"],
              "date_created" => ["January 26, 1952"]
            }
          }
        })

      # Add one to exercise date_created with format `.*[.*yyyy]`
      {:ok, entry7} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 7"],
              "date_created" => ["29 Raḥab al-Marjab 1342- رحب المرجب 1342 - [July 1923]"]
            }
          }
        })

      # Add one to exercise date_created with format `[yyyy]`
      {:ok, entry8} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 8"],
              "date_created" => ["[2010]"]
            }
          }
        })

      {:ok, entry9} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 9"],
              "date_created" => ["September [1954]"]
            }
          }
        })

      doc4 = HydrationCacheEntry.to_solr_document(entry4)
      doc5 = HydrationCacheEntry.to_solr_document(entry5)
      doc6 = HydrationCacheEntry.to_solr_document(entry6)
      doc7 = HydrationCacheEntry.to_solr_document(entry7)
      doc8 = HydrationCacheEntry.to_solr_document(entry8)
      doc9 = HydrationCacheEntry.to_solr_document(entry9)

      assert doc1[:years_is] == [2022]
      assert doc2[:years_is] == [1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005]
      assert doc3[:years_is] == nil
      assert doc4[:years_is] == [2011, 2012, 2013]
      assert doc5[:years_is] == nil
      assert doc6[:years_is] == [1952]
      assert doc7[:years_is] == [1923]
      assert doc8[:years_is] == [2010]
      assert doc9[:years_is] == [1954]

      assert doc1[:display_date_s] == "2022"
      assert doc2[:display_date_s] == "1995 - 2005"
      assert doc3[:display_date_s] == nil
      assert doc4[:display_date_s] == "2011 - 2013 (approximate)"
      assert doc5[:display_date_s] == nil
      assert doc6[:display_date_s] == "January 26, 1952"
      assert doc7[:display_date_s] == "29 Raḥab al-Marjab 1342- رحب المرجب 1342 - [July 1923]"
      assert doc8[:display_date_s] == "[2010]"
      assert doc9[:display_date_s] == "September [1954]"
    end

    test "logs dates it can't parse" do
      # date created has a bad date
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => ["test title 5"],
              "date_created" => ["un-parsable date [192?]"]
            }
          }
        })

      assert capture_log(fn -> HydrationCacheEntry.to_solr_document(entry) end) =~
               "couldn't parse date"
    end
  end
end
