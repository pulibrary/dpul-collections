defmodule DpulCollections.SolrTest do
  alias DpulCollections.Search.SearchState
  use DpulCollections.DataCase, async: true
  alias DpulCollections.Item
  alias DpulCollections.Solr
  import ExUnit.CaptureLog
  import Mock

  test ".document_count/0" do
    assert Solr.document_count() == 0
  end

  describe ".find_by_id/1" do
    test "returns a solr document" do
      assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74") == nil

      doc = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => ["test title 1"]
      }

      Solr.add([doc], active_collection())
      Solr.soft_commit(active_collection())

      assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["title_txtm"] ==
               doc["title_txtm"]
    end

    test "when called on nil or empty string returns nil" do
      FiggyTestSupport.index_record_id_directly("256df489-089d-473a-b9bb-c3585bb639af")
      FiggyTestSupport.index_record_id_directly("32b45be9-257e-444c-bc3e-89535146ae2c")
      Solr.soft_commit()

      assert Solr.find_by_id(nil) == nil
      assert Solr.find_by_id("") == nil
    end

    test "when solr returns a non-200 status" do
      with_mock Req, [:passthrough],
        post: fn _url, _ -> {:ok, %{status: 404, body: "server error"}} end do
        assert_raise Solr.Client.ServerError, fn ->
          Solr.find_by_id("docid")
        end
      end
    end

    test "when the connection is closed" do
      with_mock Req, [:passthrough],
        post: fn _url, _ -> {:error, %Req.TransportError{reason: :closed}} end do
        assert_raise Solr.Client.ServerError, fn ->
          Solr.find_by_id("docid")
        end
      end
    end
  end

  describe ".search" do
    test "returns documents in one key" do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{})
      result = Solr.search(search_state)
      assert length(Solr.search(search_state).results) == 10
      assert result.total_items == 10
    end

    test "can filter by similarity and another facet" do
      Solr.add(SolrTestSupport.mock_solr_documents(20), active_collection())
      Solr.soft_commit(active_collection())

      search_state =
        SearchState.from_params(%{"filter" => %{"similar" => "2", "format" => ["Pamphlets"]}})

      result = Solr.search(search_state)
      assert result.total_items == 10
    end

    test "can filter by multiple values, and when it does it's an OR" do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      search_state =
        SearchState.from_params(%{"filter" => %{"format" => ["Folders", "Pamphlets"]}})

      result = Solr.search(search_state)
      assert result.total_items == 10

      search_state = SearchState.from_params(%{"filter" => %{"format" => ["Folders"]}})
      result = Solr.search(search_state)
      assert result.total_items == 5
    end

    test "returns filter data" do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{})
      result = Solr.search(search_state)

      assert %{
               filter_data: %{
                 "format" => %{
                   label: "Format",
                   data: [
                     {"Folders", 5},
                     {"Pamphlets", 5}
                   ]
                 }
               }
             } = result
    end

    test "returns more than 10 filter items" do
      for n <- 1..15 do
        Solr.add(
          %{
            id: "document-#{n}",
            format_txt_sort: ["Format #{n}"],
            title_txtm: ["Title #{n}"]
          },
          active_collection()
        )
      end

      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{})
      result = Solr.search(search_state)

      assert length(result.filter_data["format"].data) == 15
    end

    test "returns filter data excluding its own filter" do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"filter" => %{"format" => ["Folders"]}})
      result = Solr.search(search_state)

      assert %{
               "format" => %{
                 label: "Format",
                 data: [
                   {"Folders", 5},
                   {"Pamphlets", 5}
                 ]
               }
             } =
               result.filter_data
    end

    test "searching without accents still returns results" do
      # Example record: https://digital-collections.princeton.edu/i/untitled/item/d50a5a8f-866e-4345-b91d-aed1841cff22
      Solr.add(
        [
          %{
            id: "spanish-example",
            title_txtm: ["Test Title"],
            summary_txtm: [
              "Sticker images depict the eyes of Venezuela's late President Hugo Chávez Frías."
            ]
          }
        ],
        active_collection()
      )

      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "Hugo Chavez"})
      result = Solr.search(search_state)

      assert length(result.results) == 1
      assert hd(result.results).id == "spanish-example"
    end

    test "searching across fields works as expected" do
      # Searching for "Ricky Rossello" should handle accents and also search
      # across the title and summary.
      FiggyTestSupport.index_record_id_directly("c66a266c-38ce-4442-90ec-e3e329e6d602")
      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "Ricky Rossello"})
      result = Solr.search(search_state)

      assert length(result.results) == 1

      # Searching for "Evo Environment" returns a record across categories /
      # title
      FiggyTestSupport.index_record_id_directly("ce55ea72-176b-4468-b486-2859822b065f")
      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "Evo environment"})
      result = Solr.search(search_state)

      assert length(result.results) == 1
    end

    test "Spanish stemming in qf improves search results" do
      # "El despertar de los trabajadores" contains "trabajadores" (plural, masculine).
      # A search for "trabajadora" (singular, feminine) won't match in title_txtm
      # but will in title_txtm_es because the analyzer performs stemming.
      Solr.add(
        [%{id: "spanish-example", title_txtm: ["El despertar de los trabajadores"]}],
        active_collection()
      )

      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "trabajadora"})
      result = Solr.search(search_state)

      assert length(result.results) == 1
      assert hd(result.results).id == "spanish-example"
    end

    test "Spanish stemming in qf allows for searching exact match titles" do
      Solr.add(
        [%{id: "spanish-example", title_txtm: ["¿Por qué votar el 6D por la revolución?"]}],
        active_collection()
      )

      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "¿Por qué votar el 6D por la revolución?"})
      result = Solr.search(search_state)

      assert length(result.results) == 1
      assert hd(result.results).id == "spanish-example"
    end

    test "English stemming in qf improves search results" do
      # A search for "updates" should find a document titled "Legislative Update"
      # because the English analyzer stems "updates" to "update".
      Solr.add(
        [%{id: "english-example", title_txtm: ["Legislative Update"]}],
        active_collection()
      )

      Solr.soft_commit(active_collection())

      search_state = SearchState.from_params(%{"q" => "updates"})
      result = Solr.search(search_state)

      assert length(result.results) == 1
      assert hd(result.results).id == "english-example"
    end

    test "can filter by two facets" do
      Solr.add(SolrTestSupport.mock_solr_documents(10), active_collection())
      Solr.soft_commit(active_collection())

      search_state =
        SearchState.from_params(%{"filter" => %{"subject" => ["Arts"], "format" => ["Folders"]}})

      result = Solr.search(search_state)

      assert %{
               "format" => %{
                 label: "Format",
                 data: [
                   {"Folders", 5},
                   {"Pamphlets", 5}
                 ]
               }
             } =
               result.filter_data
    end
  end

  describe "find_all_collections" do
    test "returns collections" do
      doc1 = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => "Doc-1",
        "file_count_i" => 1,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601()
      }

      doc2 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b3",
        "updated_at_dt" =>
          DateTime.utc_now() |> DateTime.add(-5, :minute) |> DateTime.to_iso8601(),
        "title_txtm" => "Collection-1",
        "resource_type_s" => "collection"
      }

      doc3 = %{
        "id" => "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a",
        "updated_at_dt" =>
          DateTime.utc_now() |> DateTime.add(-3, :minute) |> DateTime.to_iso8601(),
        "title_txtm" => "Collection-2",
        "resource_type_s" => "collection"
      }

      Solr.add([doc1, doc2, doc3], active_collection())
      Solr.soft_commit(active_collection())

      records = Solr.find_all_collections()

      assert Enum.count(records) == 2
      assert Enum.map(records, & &1["id"]) == Enum.map([doc2, doc3], & &1["id"])
    end
  end

  describe ".add/1" do
    test "adds a doc to the index" do
      doc = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => ["test title 1"]
      }

      assert Solr.document_count() == 0

      Solr.add([doc], active_collection())
      Solr.soft_commit(active_collection())

      assert Solr.document_count() == 1
    end

    test "can sandbox" do
      start_key = ProcessTree.get(:solr_sandbox_key)

      on_exit(fn ->
        Process.put(:solr_sandbox_key, start_key)
      end)

      doc = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => ["test title 1"]
      }

      assert Solr.document_count() == 0

      Solr.add([doc], active_collection())
      Solr.soft_commit(active_collection())

      doc = Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")
      assert doc["solr_sandbox_key_s"] == ProcessTree.get(:solr_sandbox_key)
      assert Solr.document_count() == 1

      # Change the sandbox.
      new_key = "test-change-#{System.unique_integer([:positive])}"
      Process.put(:solr_sandbox_key, new_key)
      assert Solr.document_count() == 0
      doc = Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")
      assert nil == doc

      # Put the same ID in, different title.
      Solr.add(
        [%{"id" => "3cb7627b-defc-401b-9959-42ebc4488f74", "title_txtm" => "Bla"}],
        active_collection()
      )

      Solr.soft_commit(active_collection())
      doc = Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")
      assert doc["title_txtm"] == ["Bla"]

      # Change sandbox back, make sure it's the other one.
      Process.put(:solr_sandbox_key, start_key)
      doc = Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")
      assert doc["title_txtm"] == ["test title 1"]

      # Delete all, but just in one sandbox.
      Solr.delete_all(active_collection())
      assert Solr.document_count() == 0
      Process.put(:solr_sandbox_key, new_key)
      assert Solr.document_count() == 1
    end
  end

  describe ".related_items/4" do
    test "returns similar items in the same collection" do
      docs = [
        %{
          "id" => "reference",
          "title_txtm" => ["test title 1"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "museum exhibits"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "similar",
          "title_txtm" => ["similar item"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "music"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "less-similar",
          "title_txtm" => ["item that's not as similar"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["education", "music"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "other-collection",
          "title_txtm" => ["similar item"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "music"],
          "collection_titles_ss" => ["South Asian Ephemera"],
          "file_count_i" => 1
        }
      ]

      Solr.add(docs, active_collection())
      Solr.soft_commit(active_collection())

      results =
        Solr.related_items(%Item{id: "reference", collections: ["Latin American Ephemera"]}, %{
          filter: %{"collection" => ["Latin American Ephemera"]}
        })
        |> Map.get("docs")
        |> Enum.map(&Map.get(&1, "id"))

      assert results == ["similar", "less-similar"]
    end

    test "returns similar items in the other collections" do
      docs = [
        %{
          "id" => "reference",
          "title_txtm" => ["test title 1"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "museum exhibits"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "similar-collection",
          "title_txtm" => ["similar collection"],
          "resource_type_s" => "collection",
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "museum exhibits"]
        },
        %{
          "id" => "similar",
          "title_txtm" => ["similar item"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "music"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "less-similar",
          "title_txtm" => ["item that's not as similar"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["education", "music"],
          "collection_titles_ss" => ["Latin American Ephemera"],
          "file_count_i" => 1
        },
        %{
          "id" => "other-collection",
          "title_txtm" => ["similar item"],
          "format_txt_sort" => ["pamphlets"],
          "subject_txt_sort" => ["folk art", "music"],
          "collection_titles_ss" => ["South Asian Ephemera"],
          "file_count_i" => 1
        }
      ]

      Solr.add(docs, active_collection())
      Solr.soft_commit(active_collection())

      results =
        Solr.related_items(%Item{id: "reference", collections: ["Latin American Ephemera"]}, %{
          filter: %{"collection" => "-Latin American Ephemera"}
        })
        |> Map.get("docs")
        |> Enum.map(&Map.get(&1, "id"))

      assert results == ["other-collection"]
    end
  end

  describe ".related_collections/2" do
    test "it returns collections with members that are members of the given collection" do
      [
        %{
          id: "d7c889ba-9992-494e-8fe4-2c4a9b3c3d7d",
          title_txtm: ["Latin American Ephemera"],
          resource_type_s: "collection",
          authoritative_slug_s: "lae"
        },
        %{
          id: "63547919-8acb-412c-94ca-88cfc28585f5",
          title_txtm: ["Latin American Writers at Princeton"],
          resource_type_s: "collection",
          authoritative_slug_s: "latamwriters"
        },
        %{
          "id" => "253265ef-5acb-4ce3-a6db-e2316631b6a8",
          "title_txtm" => [
            "2º Festival Artístico en Solidaridad con los Damnificados de Tlatelolco"
          ],
          "format_txt_sort" => ["Flyers"],
          "subject_txt_sort" => ["Arts", "Festivals", "Collective memory", "Protest movements"],
          "collection_titles_ss" => [
            "Latin American Ephemera",
            "Latin American Writers at Princeton"
          ],
          "file_count_i" => 1
        }
      ]
      |> Solr.add(active_collection())

      Solr.soft_commit(active_collection())

      results =
        Solr.related_collections("Latin American Ephemera")
        |> Enum.map(&Map.get(&1, "title_txtm"))
        |> List.flatten()

      assert results == ["Latin American Writers at Princeton"]
    end
  end

  describe ".generate_filter_query/1" do
    test "returns nil for a bare negation string" do
      assert Solr.generate_filter_query({"collection", "-"}) == nil
    end
  end

  describe ".recently-updated/3" do
    test "can be limited by search filters" do
      doc1 = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => "Doc-1",
        "file_count_i" => 1,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601(),
        "collection_titles_ss" => ["Test Title"]
      }

      doc2 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b3",
        "file_count_i" => 1,
        "updated_at_dt" =>
          DateTime.utc_now() |> DateTime.add(-5, :minute) |> DateTime.to_iso8601(),
        "title_txtm" => "Doc-2",
        "collection_titles_ss" => ["Test Title"]
      }

      doc3 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b4",
        "file_count_i" => 1,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "title_txtm" => "Doc-3"
      }

      Solr.add([doc1, doc2, doc3], active_collection())
      Solr.soft_commit(active_collection())

      records =
        Solr.recently_added(
          1,
          SearchState.from_params(%{"filter" => %{"collection" => "Test Title"}})
        )
        |> Map.get("docs")

      # Doc-3 would be most recent, but isn't in that collection.
      assert Enum.at(records, 0) |> Map.get("id") == doc2["id"]
    end

    test "doesn't return collections" do
      doc1 = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => "Doc-1",
        "file_count_i" => 1,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601()
      }

      doc2 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b3",
        "file_count_i" => 1,
        "updated_at_dt" =>
          DateTime.utc_now() |> DateTime.add(-5, :minute) |> DateTime.to_iso8601(),
        "title_txtm" => "Doc-2",
        "resource_type_s" => "collection"
      }

      Solr.add([doc1, doc2], active_collection())
      Solr.soft_commit(active_collection())

      records = Solr.recently_added(2) |> Map.get("docs")

      # Only returns one, and it's the non-collection.
      id = doc1["id"]
      assert [%{"id" => ^id}] = records
    end

    test "returns most recently updated solr records with images" do
      doc1 = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => "Doc-1",
        "file_count_i" => 1,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601()
      }

      doc2 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b3",
        "file_count_i" => 1,
        "updated_at_dt" =>
          DateTime.utc_now() |> DateTime.add(-5, :minute) |> DateTime.to_iso8601(),
        "title_txtm" => "Doc-2"
      }

      doc3 = %{
        "id" => "26713a31-d615-49fd-adfc-93770b4f66b4",
        "file_count_i" => 0,
        "updated_at_dt" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "title_txtm" => "Doc-3"
      }

      Solr.add([doc1, doc2, doc3], active_collection())
      Solr.soft_commit(active_collection())

      records = Solr.recently_added(1) |> Map.get("docs")

      assert Enum.at(records, 0) |> Map.get("id") == doc2["id"]
    end
  end

  test ".random/3 doesn't return collections" do
    Solr.add(%{
      "id" => "similar-collection",
      "title_txtm" => ["similar collection"],
      "resource_type_s" => "collection",
      "format_txt_sort" => ["pamphlets"],
      "subject_txt_sort" => ["folk art", "museum exhibits"],
      # This never happens right now, but to make sure we're filtering on resource type.
      "file_count_i" => 1
    })

    Solr.soft_commit()

    records = Solr.random(5, "100")

    assert %{"docs" => []} = records
  end

  test ".random/3 with two different seeds returns different results" do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.soft_commit(active_collection())

    set1 = Solr.random(5, "100")
    set2 = Solr.random(5, "999")
    assert set1 != set2
  end

  test ".random/3 with the same seed returns the same results" do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.soft_commit(active_collection())

    set1 = Solr.random(5, "100")
    set2 = Solr.random(5, "100")
    assert set1 == set2
  end

  test ".latest_document" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    assert Solr.latest_document() == nil

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.latest_document()["id"] == doc["id"]

    doc_2 = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f75",
      "title_txtm" => ["test title 1"]
    }

    Solr.add([doc_2], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.latest_document()["id"] == doc_2["id"]
  end

  describe ".delete_all/0" do
    test "with a single doc in the index" do
      doc = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => ["test title 1"]
      }

      Solr.add([doc], active_collection())
      Solr.soft_commit(active_collection())
      assert Solr.document_count() == 1

      Solr.delete_all(active_collection())
      assert Solr.document_count() == 0
    end

    test "when solr returns a non-200 status" do
      with_mock Req, [:passthrough],
        post: fn _url, _ -> {:ok, %{status: 404, body: "server error"}} end do
        assert_raise Solr.Client.ServerError, fn ->
          Solr.delete_all(active_collection())
        end
      end
    end
  end

  describe ".delete_batch/2" do
    test "when solr returns a non-200 status" do
      with_mock Req, [:passthrough],
        post: fn _url, _ -> {:ok, %{status: 404, body: "server error"}} end do
        assert_raise Solr.Client.ServerError, fn ->
          Solr.delete_batch(["doc1", "doc2"], active_collection())
        end
      end
    end
  end

  describe ".add/2" do
    test "an exception is logged when indexing a document raises a solr error" do
      doc = %{
        # No title
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74"
      }

      log = capture_log(fn -> Solr.add([doc], active_collection()) end)
      assert log =~ "Error indexing solr document"
    end

    test "a valid solr document is indexed when in the same batch as an invalid solr document" do
      valid_doc = %{
        "id" => "e0602353-4429-4405-b080-064952f9b267",
        "title_txtm" => ["test title 1"]
      }

      invalid_doc = %{
        # No title
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74"
      }

      log = capture_log(fn -> Solr.add([valid_doc, invalid_doc], active_collection()) end)
      assert log =~ "Error indexing solr document"

      Solr.soft_commit(active_collection())
      assert Solr.find_by_id(valid_doc["id"])["id"] == valid_doc["id"]
    end

    test "when the connection to solr times out" do
      doc = %{
        "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
        "title_txtm" => ["test title 1"]
      }

      with_mock Req, [:passthrough],
        post: fn _url, _ -> {:error, %Req.TransportError{reason: :timeout}} end do
        log = capture_log(fn -> Solr.add([doc], active_collection()) end)
        assert log =~ "Error indexing solr document"
        assert log =~ "Req TransportError, reason: timeout"
      end
    end
  end

  test "write operations use a default collection if none specified" do
    {:ok, response} = Solr.commit()
    assert response.body["responseHeader"]["status"] == 0
  end

  test "slug generation" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["Zilele noastre care nu vor mai fi niciodată"]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "zilele-vor-mai-niciodată"
  end

  test "slug generation whith a short title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["This is a title"]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] == "this-is-a-title"
  end

  test "slug generation with non-stopword-filtered language" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["玉機微義 : 五十卷 / 徐用誠輯 ; 劉純續輯."]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "玉機微義-五十卷-徐用誠輯-劉純續輯"
  end

  test "slug generation with rtl langauge" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["ديوان القاضي ناصح الدين ابي بكر احمد بن محمد بن الحسين الارجاني."]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "ديوان-القاضي-ناصح-الدين-ابي"
  end

  test "slug generation with ellipsis character in title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["Паук семейства СОИ…"]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "паук-семейства-сои"
  end

  test "slug generation with Spanish title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["¡¿Él no responde mis mensajes!?"]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "él-no-responde-mis-mensajes"
  end

  test "slug generation when the slug is truncated with a trailing dash" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["¿Cómo la reforma educacional beneficia a mi familia?"]
    }

    Solr.add([doc], active_collection())
    Solr.soft_commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "cómo-reforma-educacional-beneficia"
  end

  describe ".find_by_slug" do
    test "returns nothing if there's nothing with that authoritative slug" do
      assert Solr.find_by_slug("empty") == nil
    end
  end
end
