defmodule DpulCollections.Solr.IndexTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  alias DpulCollections.Solr.Index
  import SolrTestSupport

  setup do
    Solr.delete_all(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test ".connect/1 setting auth works" do
    read_index = Index.read_index()

    index = %Index{
      base_url: "http://localhost:8983",
      collection: "bla",
      username: "test",
      password: "test"
    }

    connection = Index.connect(index)
    assert connection.options.base_url == "http://localhost:8983"
    assert connection.options.auth == {:basic, "test:test"}
  end

  test ".connect/1 with no auth works" do
    read_index = Index.read_index()

    index = %Index{
      base_url: "http://localhost:8983",
      collection: "bla"
    }

    connection = Index.connect(index)
    assert connection.options.base_url == "http://localhost:8983"
    assert connection.options.auth == nil
  end

  test ".connect/1 with empty strings auth works" do
    read_index = Index.read_index()

    index = %Index{
      base_url: "http://localhost:8983",
      collection: "bla",
      username: "",
      password: ""
    }

    connection = Index.connect(index)
    assert connection.options.base_url == "http://localhost:8983"
    assert connection.options.auth == nil
  end
end
