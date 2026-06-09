defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Solr
  alias DpulCollections.Collection
  alias DpulCollections.Item
  alias DpulCollections.IndexingPipeline

  defstruct [
    :collection,
    :dc_count,
    :filtered_figgy_count,
    :total_figgy_count,
    # IDs that aren't in DC, and that's on purpose.
    :filtered_items,
    # IDs that aren't in DC, and should be.
    :missing_items,
    # IDs that aren't in Figgy, but are in DC. Probably a delete problem.
    :extra_items
  ]

  def all_collections do
    # get all the local ids / titles
    # get all the figgy ids / titles
    # compute totals, and set memberships
    Solr.find_all_collections()
    |> Enum.map(&Collection.from_solr/1)
    |> Enum.map(&from_collection/1)
  end

  def from_collection(collection = %Collection{}) do
    figgy_items = 
      IndexingPipeline.get_figgy_project_folders(collection.id) ++
        IndexingPipeline.get_figgy_collection_members(collection.id)
    # TODO: make resource to item
        # |> Enum.map(&:Item.from_
    # TODO: write a solr function for getting all the items in a collection?
    dc_items = 

    %__MODULE__{
      collection: collection,
      dc_count: dc_count(collection),
      total_figgy_count: total_figgy_count(collection)
    }
  end

  def dc_count(collection) do
    collection.title
    |> hd
    |> Solr.collection_summary()
    |> Map.get(:total_items)
  end

  def total_figgy_count(collection) do
    # We'll run both, one will be empty depending on if collection is a Figgy
    # Collection or an EphemeraProject.
    all_resources =
      IndexingPipeline.get_figgy_project_folders(collection.id) ++
        IndexingPipeline.get_figgy_collection_members(collection.id)

    length(all_resources)
  end
end
