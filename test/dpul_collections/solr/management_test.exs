defmodule DpulCollections.SolrTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  alias DpulCollections.Solr.Index
  alias DpulCollections.Solr.Management
  import SolrTestSupport

  setup do
    Solr.delete_all(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  test "create a new collection, set alias, delete a collection" do
    read_index = Index.read_index()
    write_index = Index.write_indexes() |> hd

    original_collection = Management.get_alias(read_index)
    # alias is pointing to the collection created during setup
    assert original_collection == "dpulc1"

    old_index = %Index{read_index | collection: original_collection}
    new_index = %Index{write_index | collection: "new_index1"}

    # creating new collection
    refute Management.collection_exists?(new_index)
    Management.create_collection(new_index)
    assert Management.collection_exists?(new_index)

    # setting alias to new collection
    Management.set_alias(new_index, read_index.collection)
    assert Management.get_alias(read_index) == "new_index1"

    # delete new index / clean up test
    Management.set_alias(old_index, read_index.collection)
    Management.delete_collection(new_index)
    refute Management.collection_exists?(new_index)
  end

  test "creating an existing collection is a no-op" do
    write_index = Index.write_indexes() |> hd
    response = Management.create_collection(write_index)
    # Most importantly, it doesn't error, but here's an assertion as a coherence
    # check
    assert response.body["exception"]["msg"] == "collection already exists: dpulc1"
  end
end
