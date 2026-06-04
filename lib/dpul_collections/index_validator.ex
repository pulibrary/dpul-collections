defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Solr
  alias DpulCollections.Collection

  defstruct [
    :collection,
    :dc_count,
    :filtered_figgy_count,
    :total_figgy_count,
    :filtered_ids,
    :missing_ids
  ]

  def all_collections do
    Solr.find_all_collections()
    |> Enum.map(&Collection.from_solr/1)
    |> Enum.map(&from_collection/1)
  end

  def from_collection(collection = %Collection{}) do
    %__MODULE__{
      collection: collection,
      dc_count: dc_count(collection)
    }
  end

  def dc_count(collection) do
    collection.title
    |> hd
    |> Solr.collection_summary()
    |> Map.get(:total_items)
  end
end
