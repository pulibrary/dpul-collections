defmodule DpulCollections.Collection do
  alias DpulCollections.Item
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollections.Solr
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defstruct [
    :id,
    :slug,
    :title,
    :tagline,
    :description,
    :item_count,
    categories: [],
    genres: [],
    languages: [],
    geographic_origins: [],
    featured_items: []
  ]

  def from_slug(slug) do
    Solr.find_by_slug(slug)
    |> from_solr()
  end

  def get_featured_items(label) do
    params =
      SearchState.from_params(%{
        "filter" => %{"project" => label, "featured" => true},
        "per_page" => "4"
      })

    Solr.query(params)["docs"] |> Enum.map(&Item.from_solr/1)
  end

  def from_solr(doc = %{}) do
    summary = project_summary("South Asian Ephemera")

    %__MODULE__{
      id: doc["id"],
      slug: doc["authoritative_slug_s"],
      title: Map.get(doc, "title_txtm", []),
      tagline: doc |> Map.get("tagline_txt_sort", []) |> hd,
      description: doc |> Map.get("description_txtm", []) |> hd,
      item_count: summary.count,
      categories: summary.categories,
      genres: summary.genres,
      languages: summary.languages,
      geographic_origins: summary.geographic_origins,
      featured_items: get_featured_items("South Asian Ephemera")
    }
  end

  defp project_summary(label) do
    summary = Solr.project_summary(label)

    %{
      count: summary["numFound"],
      languages: summary["facets"]["language_txt_sort"],
      geographic_origins: summary["facets"]["geographic_origin_txt_sort"],
      categories: summary["facets"]["categories_txt_sort"],
      genres: summary["facets"]["genre_txt_sort"]
    }
  end
end
