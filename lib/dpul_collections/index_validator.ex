defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Solr
  alias DpulCollections.Collection
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
    |> Enum.sort_by(&Map.get(&1, :title))
    |> Enum.map(&from_collection/1)
  end

  def from_collection(collection = %Collection{}) do
    # Grab both - if it's an EphemeraProject it'll get folders deep, if it's a
    # Collection then it'll get all members.
    figgy_ids =
      IndexingPipeline.get_figgy_project_folders(collection.id) ++
        IndexingPipeline.get_figgy_collection_members(collection.id)

    dc_ids =
      SearchState.from_params(%{})
      |> Map.put(:extra_params, fl: "id", rows: 200_000)
      |> SearchState.set_filter("collection", collection.title)
      |> Solr.query()
      |> Map.get("docs")
      |> Enum.map(&Map.get(&1, "id"))

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
