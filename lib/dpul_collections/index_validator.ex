defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Solr
  alias DpulCollections.Collection
  alias DpulCollections.Item
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.SearchLive.SearchState

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
    # compute totals, and set memberships
    Solr.find_all_collections()
    |> Enum.map(&Collection.from_solr/1)
    |> Enum.map(&from_collection/1)
  end

  def from_collection(collection = %Collection{}) do
    figgy_ids =
      (IndexingPipeline.get_figgy_project_folders(collection.id) ++
         IndexingPipeline.get_figgy_collection_members(collection.id))
      |> Enum.map(&Map.get(&1, :id))

    # TODO: make resource to item
    # |> Enum.map(&:Item.from_
    dc_ids =
      %{"per_page" => "2000000"}
      |> SearchState.from_params()
      |> SearchState.set_filter("collection", collection.title)
      |> Solr.search()
      |> Map.get(:results)
      |> Enum.map(&Map.get(&1, :id))

    %__MODULE__{
      collection: collection,
      dc_count: dc_count(collection),
      total_figgy_count: total_figgy_count(collection),
      missing_items: figgy_ids -- dc_ids
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
