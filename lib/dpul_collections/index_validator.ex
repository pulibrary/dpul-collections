defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Solr
  alias DpulCollections.Item

  def all_collections do
    Solr.find_all_collections()
    |> Enum.map(&Item.from_solr/1)
  end
end
