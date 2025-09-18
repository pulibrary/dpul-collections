defmodule DpulCollections.Collection do
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
    geographic_origins: []
  ]

  def from_slug("sae") do
    summary = project_summary("South Asian Ephemera")

    %__MODULE__{
      id: "f99af4de-fed4-4baa-82b1-6e857b230306",
      slug: "sae",
      title: "South Asian Ephemera",
      tagline:
        "Discover voices of change across South Asia through contemporary pamphlets, flyers, and documents that capture the region's social movements, politics, and cultural expressions.",
      description: """
      The South Asian Ephemera Collection complements Princeton's already robust Digital Archive of Latin American and Caribbean Ephemera. The goal of the collection is to provide a diverse selection of resources that span a variety of subjects and languages and support interdisciplinary scholarship in South Asian Studies.
      At present, the collection is primarily composed of contemporary ephemera and items from the latter half of the twentieth century, though users will also find items originating from earlier dates. Common genres in the collection include booklets, pamphlets, leaflets, and flyers. These items were produced by a variety of individuals and organizations including political parties, non-governmental organizations, public policy think tanks, activists, and others and were meant to promote their views, positions, agendas, policies, events, and activities.
      Every effort is being made to represent each country in the region. As the collection grows over time, PUL will provide increasingly balanced coverage of the area.
      """,
      item_count: summary.count,
      categories: summary.categories,
      genres: summary.genres,
      languages: summary.languages,
      geographic_origins: summary.geographic_origins
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
