defmodule DpulCollections.IndexValidator do
  alias DpulCollections.Collection
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.Solr
  alias DpulCollectionsWeb.SearchLive.SearchState

  defstruct [
    :collection,
    :dc_count,
    :public_complete_figgy_count,
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
      dc_count: length(dc_ids),
      public_complete_figgy_count: length(figgy_ids),
      missing_items: figgy_ids -- dc_ids,
      extra_items: dc_ids -- figgy_ids
    }
  end
end
