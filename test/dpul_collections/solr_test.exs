defmodule DpulCollections.SolrTest do
  use DpulCollections.DataCase, async: true
  alias DpulCollections.Item
  alias DpulCollections.Solr
  import SolrTestSupport
  import ExUnit.CaptureLog

  test ".document_count/0" do
    assert Solr.document_count() == 0
  end

  test ".find_by_id/1" do
    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74") == nil

    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["title_txtm"] ==
             doc["title_txtm"]
  end

  test ".add/1" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    assert Solr.document_count() == 0

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.document_count() == 1
  end

  describe ".related_items/1" do
    test "returns similar items in the same collection" do
      docs = [
        %{
          "id" => "reference",
          "title_txtm" => ["test title 1"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "museum exhibits"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "similar",
          "title_txtm" => ["similar item"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "music"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "less-similar",
          "title_txtm" => ["item that's not as similar"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["education", "music"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "other-project",
          "title_txtm" => ["similar item"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "music"],
          "ephemera_project_title_s" => "South Asian Ephemera"
        }
      ]

      Solr.add(docs, active_collection())
      Solr.commit(active_collection())

      results =
        Solr.related_items(%Item{id: "reference", project: "Latin American Ephemera"}, %{
          filter: %{"project" => "Latin American Ephemera"}
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
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "museum exhibits"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "similar",
          "title_txtm" => ["similar item"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "music"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "less-similar",
          "title_txtm" => ["item that's not as similar"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["education", "music"],
          "ephemera_project_title_s" => "Latin American Ephemera"
        },
        %{
          "id" => "other-project",
          "title_txtm" => ["similar item"],
          "genre_txtm" => ["pamphlets"],
          "subject_txtm" => ["folk art", "music"],
          "ephemera_project_title_s" => "South Asian Ephemera"
        }
      ]

      Solr.add(docs, active_collection())
      Solr.commit(active_collection())

      results =
        Solr.related_items(%Item{id: "reference", project: "Latin American Ephemera"}, %{
          filter: %{"project" => "-Latin American Ephemera"}
        })
        |> Map.get("docs")
        |> Enum.map(&Map.get(&1, "id"))

      assert results == ["other-project"]
    end
  end

  test ".recently_updated/1 returns most recently updated solr records with images" do
    doc1 = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => "Doc-1",
      "file_count_i" => 1,
      "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.to_iso8601()
    }

    doc2 = %{
      "id" => "26713a31-d615-49fd-adfc-93770b4f66b3",
      "file_count_i" => 1,
      "updated_at_dt" => DateTime.utc_now() |> DateTime.add(-5, :minute) |> DateTime.to_iso8601(),
      "title_txtm" => "Doc-2"
    }

    doc3 = %{
      "id" => "26713a31-d615-49fd-adfc-93770b4f66b4",
      "file_count_i" => 0,
      "updated_at_dt" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "title_txtm" => "Doc-3"
    }

    Solr.add([doc1, doc2, doc3], active_collection())
    Solr.commit(active_collection())

    records = Solr.recently_updated(1) |> Map.get("docs")

    assert Enum.at(records, 0) |> Map.get("id") == doc2["id"]
  end

  test ".random/3 with two different seeds returns different results" do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())

    set1 = Solr.random(5, "100")
    set2 = Solr.random(5, "999")
    assert set1 != set2
  end

  test ".random/3 with the same seed returns the same results" do
    Solr.add(SolrTestSupport.mock_solr_documents(), active_collection())
    Solr.commit(active_collection())

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
    Solr.commit(active_collection())

    assert Solr.latest_document()["id"] == doc["id"]

    doc_2 = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f75",
      "title_txtm" => ["test title 1"]
    }

    Solr.add([doc_2], active_collection())
    Solr.commit(active_collection())

    assert Solr.latest_document()["id"] == doc_2["id"]
  end

  test ".delete_all/0" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["test title 1"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())
    assert Solr.document_count() == 1

    Solr.delete_all(active_collection())
    assert Solr.document_count() == 0
  end

  setup context do
    if solr_settings = context[:solr_settings] do
      Process.put(:dpul_collections_solr, solr_settings)
    end

    :ok
  end

  @tag solr_settings: %{
         base_url: "http://localhost:8983",
         read_collection: "bla",
         username: "test",
         password: "test"
       }
  test ".client/0 setting auth works" do
    client = Solr.client()
    assert client.options.base_url == "http://localhost:8983"
    assert client.options.auth == {:basic, "test:test"}
  end

  @tag solr_settings: %{base_url: "http://localhost:8983", read_collection: "bla", username: ""}
  test ".client/0 with no auth works" do
    client = Solr.client()
    assert client.options.base_url == "http://localhost:8983"
    assert client.options.auth == nil
  end

  test "write operations use a default collection if none specified" do
    {:ok, response} = Solr.commit()
    assert response.body["responseHeader"]["status"] == 0
  end

  test "create a new collection, set alias, delete a collection", %{collection: collection} do
    new_collection = "new_index#{Ecto.UUID.generate()}"
    assert Solr.collection_exists?(new_collection) == false

    Solr.create_collection(new_collection)
    assert Solr.collection_exists?(new_collection) == true

    # alias is pointing to the collection created during setup
    original_collection = Solr.get_alias()
    assert original_collection == "#{collection}"
    Solr.set_alias(new_collection)
    assert Solr.get_alias() == new_collection
    Solr.set_alias(original_collection)

    Solr.delete_collection(new_collection)
    assert Solr.collection_exists?(new_collection) == false
  end

  test "creating an existing collection is a no-op" do
    response = Solr.create_collection("dpulc1")
    # Most importantly, it doesn't error, but here's an assertion as a coherence
    # check
    assert response.body["exception"]["msg"] == "collection already exists: dpulc1"
  end

  test "slug generation" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["Zilele noastre care nu vor mai fi niciodată"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "zilele-vor-mai-niciodată"
  end

  test "slug generation whith a short title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["This is a title"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] == "this-is-a-title"
  end

  test "slug generation with non-stopword-filtered language" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["玉機微義 : 五十卷 / 徐用誠輯 ; 劉純續輯."]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "玉機微義-五十卷-徐用誠輯-劉純續輯"
  end

  test "slug generation with rtl langauge" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["ديوان القاضي ناصح الدين ابي بكر احمد بن محمد بن الحسين الارجاني."]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "ديوان-القاضي-ناصح-الدين-ابي"
  end

  test "slug generation with ellipsis character in title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["Паук семейства СОИ…"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "паук-семейства-сои"
  end

  test "slug generation with Spanish title" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["¡¿Él no responde mis mensajes!?"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "él-no-responde-mis-mensajes"
  end

  test "slug generation when the slug is truncated with a trailing dash" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_txtm" => ["¿Cómo la reforma educacional beneficia a mi familia?"]
    }

    Solr.add([doc], active_collection())
    Solr.commit(active_collection())

    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["slug_s"] ==
             "cómo-reforma-educacional-beneficia"
  end

  test "an exception is logged when indexing a document raises a solr error" do
    doc = %{
      # No title
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74"
    }

    assert capture_log(fn -> Solr.add([doc], active_collection()) end) =~
             "error indexing solr document"
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

    assert capture_log(fn -> Solr.add([valid_doc, invalid_doc], active_collection()) end) =~
             "error indexing solr document"

    Solr.commit(active_collection())
    assert Solr.find_by_id(valid_doc["id"])["id"] == valid_doc["id"]
  end
end
