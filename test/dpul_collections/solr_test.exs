defmodule DpulCollections.SolrTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr

  setup do
    Solr.delete_all()
    :ok
  end

  test ".document_count/0" do
    assert Solr.document_count() == 0
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
end
