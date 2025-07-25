defmodule FiggyTestFixtures do
  alias DpulCollections.IndexingPipeline.DatabaseProducer.CacheEntryMarker
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  # These are the first three known resource markers in the test database.
  # They're here so that if they change, we don't have to change them in the
  # whole test suite.
  @spec markers :: {ProcessorMarker.marker(), ProcessorMarker.marker(), ProcessorMarker.marker()}
  def markers do
    marker1 = %CacheEntryMarker{
      timestamp: ~U[2015-09-25 19:41:03.558595Z],
      id: "3da68e1c-06af-4d17-8603-fc73152e1ef7"
    }

    marker2 = %CacheEntryMarker{
      timestamp: ~U[2015-09-27 19:41:03.558595Z],
      id: "e5603178-7f7c-48cb-b712-0ba705a0f1da"
    }

    marker3 = %CacheEntryMarker{
      timestamp: ~U[2015-09-29 19:41:03.558595Z],
      id: "f8238277-4af4-4232-993e-4398c5186fa6"
    }

    {marker1, marker2, marker3}
  end

  def ephemera_folder_marker do
    FiggyTestSupport.first_ephemera_folder()
    |> CacheEntryMarker.from()
  end

  def resources_from_deletion_markers(deletion_markers) do
    deletion_markers
    |> Enum.map(fn marker ->
      %{
        "resource_id" => [%{"id" => id}],
        "resource_type" => [resource_type],
        "deleted_object" => [deleted_object]
      } = marker.metadata

      %{"title" => title, "created_at" => created_at, "updated_at" => updated_at} = deleted_object
      {:ok, utc_created_at, _} = DateTime.from_iso8601(created_at)
      {:ok, utc_updated_at, _} = DateTime.from_iso8601(updated_at)

      %Figgy.Resource{
        id: id,
        internal_resource: resource_type,
        metadata: %{
          "title" => title,
          "visibility" => ["open"],
          "state" => ["complete"],
          "member_ids" => [%{"id" => "06838583-59a4-4ab8-ac65-2b5ea9ee6425"}]
        },
        created_at: utc_created_at |> DateTime.add(-365, :day),
        updated_at: utc_updated_at |> DateTime.add(-365, :day)
      }
    end)
  end

  def hydration_cache_entries(cache_version \\ 0) do
    # This id actually corresponds to an EphemeraTerm
    # description, date_created, date range and other metadata taken from
    #   26713a31-d615-49fd-adfc-93770b4f66b3
    {:ok, entry1} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
        source_cache_order: ~U[2018-03-09 20:19:33.414040Z],
        data: %{
          "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
          "internal_resource" => "EphemeraFolder",
          "created_at" => "2023-05-11T18:45:18.994187Z",
          "updated_at" => "2024-09-25T19:41:03.558595Z",
          "metadata" => %{
            "title" => ["test title 1"],
            "alternative_title" => ["Zaib-un-Nisa", "Zaibunnisa"],
            "iiif_manifest_url" =>
              "https://figgy.princeton.edu/concern/ephemera_folders/42b8f9d4-1ab0-4622-b4a9-96ed4c2bec71/manifest",
            "barcode" => ["barcode"],
            "content_warning" => ["content warning"],
            "contributor" => ["contributor"],
            "creator" => ["creator"],
            "date_created" => ["2022"],
            "date_range" => [
              %{
                "approximate" => "0",
                "created_at" => nil,
                "end" => [],
                "id" => nil,
                "internal_resource" => "DateRange",
                "new_record" => true,
                "optimistic_lock_token" => [],
                "start" => [],
                "updated_at" => nil
              }
            ],
            "description" => ["Asra-Panahi", "Berlin-Protest", "Elnaz-Rekabi"],
            "folder_number" => ["1"],
            "height" => ["200"],
            "holding_location" => ["holding location"],
            "keywords" => ["keyword"],
            "page_count" => ["4"],
            "provenance" => ["provenance"],
            "publisher" => ["publisher"],
            "rights_statement" => [%{"@id" => "http://rightsstatements.org/vocab/NKC/1.0/"}],
            "series" => ["series"],
            "sort_title" => ["sort_title"],
            "transliterated_title" => ["transliterated_title"],
            "width" => ["200"],
            "member_ids" => [
              %{"id" => "f60ce0c9-57fc-4820-b70d-49d1f2b248f9"},
              %{"id" => "d798d940-0740-4854-8f70-60217ec8c2e4"},
              %{"id" => "31d69702-4d4e-4e07-a65c-a30f62d096fd"},
              %{"id" => "899b015e-0e92-4b3d-a300-4a50fe641c11"},
              %{"id" => "39f54327-7739-4184-90ca-5b78fac3ca64"},
              %{"id" => "5e53e486-1bb8-45ee-bc35-adaa708f35ef"},
              %{"id" => "d13ad936-bf2c-4a53-8bc1-a20bf6841b74"},
              %{"id" => "86982ae7-3f95-4e77-aecb-14ad8e5710b7"},
              %{"id" => "725a3fac-820b-4333-9147-99790de6d1fe"},
              %{"id" => "ded111e0-26c2-4afc-89b8-4ad4ece3275a"},
              %{"id" => "f58a6245-6b83-4cff-a61f-cc6aa675a0ef"},
              %{"id" => "5437c9fe-e4c7-4f93-bf2c-ad9afee75bf5"},
              %{"id" => "ce66d035-5dd5-4df1-b825-d02746f9c11a"},
              %{"id" => "703c1ca1-2801-45fe-b2c5-607ec413f619"},
              %{"id" => "87dd1c80-3c94-4580-9273-dd54173a99f0"},
              %{"id" => "0eb9e3ae-fc5f-4902-8bbb-8706f081844e"},
              %{"id" => "171268c2-9565-4418-b5f8-a52c11ac00ec"},
              %{"id" => "6635328f-3b7e-4026-a0c5-4288e42254ed"},
              %{"id" => "4b8da379-2618-4aa4-8632-58e57dca0803"},
              %{"id" => "9887e5ab-2f82-4feb-be67-e2f726511c88"},
              %{"id" => "b6c8c6c3-5f0e-4334-82d1-cc39da657a25"},
              %{"id" => "9bbce8ac-a2e3-4200-8100-075273cf7d72"},
              %{"id" => "660a8add-ba14-445b-8371-73fba8704eb3"},
              %{"id" => "3f23a474-b08c-4b52-9ad8-930ff962a8cf"},
              %{"id" => "9b036f96-5080-48dc-9f32-cf9659bb0764"},
              %{"id" => "b38427c2-6126-41ce-8624-b1c435378f0c"},
              %{"id" => "994ee133-c117-40c2-89b5-0f6b7a705559"}
            ]
          }
        }
      })

    # date range data taken from 4c8cf820-69f1-4b0e-bf76-41b339af7c50
    {:ok, entry2} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "69990556-434c-476a-9043-bbf9a1bda5a4",
        source_cache_order: ~U[2018-03-09 20:19:34.465203Z],
        data: %{
          "id" => "69990556-434c-476a-9043-bbf9a1bda5a4",
          "internal_resource" => "EphemeraFolder",
          "metadata" => %{
            "title" => ["test title 2"],
            "description" => [],
            "alternative_title" => [],
            "content_warning" => [""],
            "date_created" => [],
            "member_ids" => [],
            "date_range" => [
              %{
                "approximate" => nil,
                "created_at" => nil,
                "end" => ["2005"],
                "id" => nil,
                "internal_resource" => "DateRange",
                "new_record" => true,
                "start" => ["1995"],
                "updated_at" => nil
              }
            ]
          }
        }
      })

    {:ok, entry3} =
      IndexingPipeline.write_hydration_cache_entry(%{
        cache_version: cache_version,
        record_id: "47276197-e223-471c-99d7-405c5f6c5285",
        source_cache_order: ~U[2018-03-09 20:19:34.486004Z],
        data: %{
          "id" => "47276197-e223-471c-99d7-405c5f6c5285",
          "internal_resource" => "EphemeraFolder",
          "metadata" => %{"title" => ["test title"]}
        }
      })

    {entry1, entry2, entry3}
  end

  def hydration_cache_markers(cache_version \\ 0) do
    {entry1, entry2, entry3} = hydration_cache_entries(cache_version)

    marker1 = %CacheEntryMarker{
      timestamp: entry1.cache_order,
      id: entry1.record_id
    }

    marker2 = %CacheEntryMarker{
      timestamp: entry2.cache_order,
      id: entry2.record_id
    }

    marker3 = %CacheEntryMarker{
      timestamp: entry3.cache_order,
      id: entry3.record_id
    }

    {marker1, marker2, marker3}
  end

  def transformation_cache_markers(cache_version \\ 0) do
    {:ok, entry1} =
      IndexingPipeline.write_transformation_cache_entry(%{
        cache_version: cache_version,
        record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
        source_cache_order: ~U[2018-03-09 20:19:33.414040Z],
        data: %{
          "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
          "title_txtm" => ["test title 1"]
        }
      })

    {:ok, entry2} =
      IndexingPipeline.write_transformation_cache_entry(%{
        cache_version: cache_version,
        record_id: "69990556-434c-476a-9043-bbf9a1bda5a4",
        source_cache_order: ~U[2018-03-09 20:19:34.465203Z],
        data: %{
          "id" => "69990556-434c-476a-9043-bbf9a1bda5a4",
          "title_txtm" => ["test title 2"]
        }
      })

    {:ok, entry3} =
      IndexingPipeline.write_transformation_cache_entry(%{
        cache_version: cache_version,
        record_id: "47276197-e223-471c-99d7-405c5f6c5285",
        source_cache_order: ~U[2018-03-09 20:19:34.486004Z],
        data: %{
          "id" => "47276197-e223-471c-99d7-405c5f6c5285",
          "title_txtm" => ["test title 3"]
        }
      })

    marker1 = %CacheEntryMarker{
      timestamp: entry1.cache_order,
      id: entry1.record_id
    }

    marker2 = %CacheEntryMarker{
      timestamp: entry2.cache_order,
      id: entry2.record_id
    }

    marker3 = %CacheEntryMarker{
      timestamp: entry3.cache_order,
      id: entry3.record_id
    }

    {marker1, marker2, marker3}
  end
end
