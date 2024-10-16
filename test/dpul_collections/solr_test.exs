defmodule DpulCollections.SolrTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    on_exit(fn -> Solr.delete_all() end)
  end

  test ".document_count/0" do
    assert Solr.document_count() == 0
  end

  test ".find_by_id/1" do
    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74") == nil

    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_ss" => ["test title 1"]
    }

    Solr.add([doc])
    Solr.commit()
    assert Solr.find_by_id("3cb7627b-defc-401b-9959-42ebc4488f74")["title_ss"] == doc["title_ss"]
  end

  test ".add/1" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_ss" => ["test title 1"]
    }

    assert Solr.document_count() == 0

    Solr.add([doc])
    Solr.commit()

    assert Solr.document_count() == 1
  end

  test ".latest_document" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_ss" => ["test title 1"]
    }

    assert Solr.latest_document() == nil

    Solr.add([doc])
    Solr.commit()

    assert Solr.latest_document()["id"] == doc["id"]

    doc_2 = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f75",
      "title_ss" => ["test title 1"]
    }

    Solr.add([doc_2])
    Solr.commit()

    assert Solr.latest_document()["id"] == doc_2["id"]
  end

  test ".delete_all/0" do
    doc = %{
      "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
      "title_ss" => ["test title 1"]
    }

    Solr.add([doc])
    Solr.commit()
    assert Solr.document_count() == 1

    Solr.delete_all()
    assert Solr.document_count() == 0
  end

  setup context do
    if solr_settings = context[:solr_settings] do
      existing_env = Application.fetch_env!(:dpul_collections, :solr)
      Application.put_env(:dpul_collections, :solr, solr_settings)
      on_exit(fn -> Application.put_env(:dpul_collections, :solr, existing_env) end)
    end

    :ok
  end

  @tag solr_settings: %{url: "http://localhost:8983/solr/bla", username: "test", password: "test"}
  test ".client/0 setting auth works" do
    client = Solr.client()
    assert client.options.base_url == "http://localhost:8983/solr/bla"
    assert client.options.auth == {:basic, "test:test"}
  end

  @tag solr_settings: %{url: "http://localhost:8983/solr/bla", username: ""}
  test ".client/0 with no auth works" do
    client = Solr.client()
    assert client.options.base_url == "http://localhost:8983/solr/bla"
    assert client.options.auth == nil
  end
end
