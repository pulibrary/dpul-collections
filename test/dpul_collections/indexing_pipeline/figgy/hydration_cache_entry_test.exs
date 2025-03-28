defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntryTest do
  use DpulCollections.DataCase
  import ExUnit.CaptureLog
  require Logger

  alias DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry
  alias DpulCollections.IndexingPipeline

  describe "to_solr_document/1" do
    test "indexes everything it needs to" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      assert %{
               alternative_title_txtm: ["Zaib-un-Nisa", "Zaibunnisa"],
               barcode_txtm: ["barcode"],
               content_warning_txtm: ["content warning"],
               contributor_txtm: ["contributor"],
               creator_txtm: ["creator"],
               description_txtm: ["Asra-Panahi", "Berlin-Protest", "Elnaz-Rekabi"],
               digitized_at_dt: "2023-05-11T18:45:18.994187Z",
               folder_number_txtm: ["1"],
               height_txtm: ["200"],
               holding_location_txtm: ["holding location"],
               keywords_txtm: ["keyword"],
               page_count_txtm: ["4"],
               provenance_txtm: ["provenance"],
               publisher_txtm: ["publisher"],
               rights_statement_txtm: ["No Known Copyright"],
               series_txtm: ["series"],
               sort_title_txtm: ["sort_title"],
               transliterated_title_txtm: ["transliterated_title"],
               width_txtm: ["200"]
             } = doc1

      assert %{
               alternative_title_txtm: [],
               content_warning_txtm: [],
               description_txtm: [],
               digitized_at_dt: nil
             } = doc2

      assert %{
               alternative_title_txtm: nil,
               description_txtm: nil,
               digitized_at_dt: nil
             } = doc3
    end

    test "includes descriptions if found" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      assert doc1[:description_txtm] == ["Asra-Panahi", "Berlin-Protest", "Elnaz-Rekabi"]
      assert doc2[:description_txtm] == []
      assert doc3[:description_txtm] == nil
    end

    test "indexes file_count_i" do
      entries =
        FiggyTestFixtures.hydration_cache_entries()
        |> Tuple.to_list()

      [doc1, doc2, _doc3] = Enum.map(entries, &HydrationCacheEntry.to_solr_document/1)

      assert doc1[:file_count_i] == 27
      assert doc2[:file_count_i] == 0
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
            "resources" => %{
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
              "title" => ["test title 4"],
              "thumbnail_id" => [%{"id" => "1"}]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      # This is the pyramidal derivative.
      assert doc[:image_service_urls_ss] == [
               "https://iiif-cloud.princeton.edu/iiif/2/0c%2Fff%2F89%2F0cff895a01ea48959c3da8c6eaab4017%2Fintermediate_file"
             ]

      # Has thumbnail url
      assert doc[:primary_thumbnail_service_url_s] ==
               "https://iiif-cloud.princeton.edu/iiif/2/0c%2Fff%2F89%2F0cff895a01ea48959c3da8c6eaab4017%2Fintermediate_file"
    end

    test "extracts metadata from the parent resource" do
      # Add FileMetadata with both a JP2/Pyramidal derivative, to ensure it
      # picks the pyramidal
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{
              "82624edb-c360-4d8a-b202-f103ee639e8e" => %{
                "id" => "82624edb-c360-4d8a-b202-f103ee639e8e",
                "internal_resource" => "EphemeraBox",
                "metadata" => %{
                  "box_number" => ["box 1"]
                }
              }
            }
          },
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "member_ids" => [%{"id" => "1"}],
              "cached_parent_id" => [%{"id" => "82624edb-c360-4d8a-b202-f103ee639e8e"}],
              "title" => ["test title 4"]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      assert doc[:box_number_txtm] == ["box 1"]
    end

    test "extracts controlled vocabulary terms with a label" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{
              "1" => %{
                "id" => "1",
                "internal_resource" => "EphemeraTerm",
                "metadata" => %{
                  "label" => []
                }
              },
              "2" => %{
                "id" => "2",
                "internal_resource" => "EphemeraTerm",
                "metadata" => %{
                  "label" => ["Term2"]
                }
              }
            }
          },
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "genre" => [%{"id" => "1"}, %{"id" => "2"}],
              "title" => ["test title 4"]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      assert doc[:genre_txtm] == ["Term2"]
    end

    test "uses first image service url when there is no thumbnail_id property" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{
              "1" => %{
                "internal_resource" => "FileSet",
                "id" => "9ad621a7b-01ea-4895-9c3d-a8c6eaab4013",
                "metadata" => %{
                  "file_metadata" => [
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

      assert doc[:primary_thumbnail_service_url_s] ==
               "https://iiif-cloud.princeton.edu/iiif/2/0c%2Fff%2F89%2F0cff895a01ea48959c3da8c6eaab4017%2Fintermediate_file"
    end

    test "uses first image service url when thumbnail id does not point to related FileSet" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{
              "1" => %{
                "internal_resource" => "FileSet",
                "id" => "9ad621a7b-01ea-4895-9c3d-a8c6eaab4013",
                "metadata" => %{
                  "file_metadata" => [
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
              "title" => ["test title 4"],
              "thumbnail_id" => [%{"id" => "9"}]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      assert doc[:primary_thumbnail_service_url_s] ==
               "https://iiif-cloud.princeton.edu/iiif/2/0c%2Fff%2F89%2F0cff895a01ea48959c3da8c6eaab4017%2Fintermediate_file"
    end

    test "does not add a thumbnail service url when there are no image members" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{}
          },
          data: %{
            "id" => "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "member_ids" => [],
              "title" => ["test title 4"]
            }
          }
        })

      doc = HydrationCacheEntry.to_solr_document(entry)

      assert doc[:primary_thumbnail_service_url_s] == nil
    end

    test "can handle when members do not have the correct file metadata type" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "0cff895a-01ea-4895-9c3d-a8c6eaab4013",
          source_cache_order: ~U[2018-03-09 20:19:35.465203Z],
          related_data: %{
            "resources" => %{
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

    test "an empty solr document is returned with a empty title field" do
      {:ok, entry} =
        IndexingPipeline.write_hydration_cache_entry(%{
          cache_version: 0,
          record_id: "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
          source_cache_order: ~U[2018-03-09 20:19:36.465203Z],
          data: %{
            "id" => "f134f41f-63c5-4fdf-b801-0774e3bc3b2d",
            "internal_resource" => "EphemeraFolder",
            "metadata" => %{
              "title" => [],
              "date_created" => ["2022"]
            }
          }
        })

      assert %{title_txtm: ["[Missing Title]"]} = HydrationCacheEntry.to_solr_document(entry)
    end
  end
end
