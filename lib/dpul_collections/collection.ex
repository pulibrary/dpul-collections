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

  def from_slug(_slug) do
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
      # I don't really know if these should be in here, but for now it's probably fine.
      item_count: summary.count,
      # These should probably come from facet data.
      categories: get_categories(),
      genres: get_genres(),
      languages: get_languages(),
      geographic_origins: get_geographic_origins()
    }
  end

  defp project_summary(label) do
    summary = Solr.project_summary(label)

    %{
      count: summary["numFound"]
    }
  end

  defp get_categories do
    [
      {"Politics and government", 1166},
      {"Religion", 767},
      {"Socioeconomic conditions and development", 527},
      {"Gender and sexuality", 473},
      {"Human and Civil Rights", 432},
      {"Arts and culture", 372},
      {"Minorities, ethnic and racial groups", 321},
      {"Economics", 284},
      {"Environment and ecology", 262},
      {"Education", 254},
      {"Agrarian and rural issues", 249},
      {"History", 220},
      {"Children and youth", 182},
      {"Health", 168},
      {"Labor", 158},
      {"Tourism", 82}
    ]
  end

  defp get_genres do
    [
      {"Booklets", 758},
      {"Reports", 559},
      {"Serials", 447},
      {"Pamphlets", 334},
      {"News clippings", 279},
      {"Posters", 260},
      {"Brochures", 182},
      {"Flyers", 54},
      {"Leaflets", 44},
      {"Manuscripts", 41},
      {"Pedagogical materials", 37},
      {"Electoral paraphernalia", 17},
      {"Stickers", 11},
      {"Correspondence", 8},
      {"Postcards", 6},
      {"Advertisements", 4},
      {"Maps", 3},
      {"Calendars", 2},
      {"Forms", 2},
      {"Games", 1}
    ]
  end

  defp get_languages do
    [
      {"English", 2015},
      {"Urdu", 320},
      {"Hindi", 226},
      {"Sinhala", 143},
      {"Nepali", 129},
      {"Telugu", 118},
      {"Assamese", 72},
      {"Tamil", 67},
      {"Bengali", 54},
      {"Arabic", 47},
      {"Gujarati", 26},
      {"Oriya", 25},
      {"Sanskrit", 14},
      {"Marathi", 12},
      {"Persian", 12},
      {"Kannada", 8},
      {"Sinhala | Sinhalese", 7},
      {"Dzongkha", 4},
      {"Esperanto", 4},
      {"Malayalam", 4},
      {"Pushto", 4},
      {"Italian", 3},
      {"Sino-Tibetan languages", 3},
      {"French", 2},
      {"Pali", 2},
      {"Panjabi", 2},
      {"Spanish", 2},
      {"Chhattisgarhi", 1},
      {"Divehi", 1},
      {"Divehi | Dhivehi | Maldivian", 1},
      {"German", 1},
      {"Indic languages", 1},
      {"Nepal Bhasa", 1},
      {"Panjabi | Punjabi", 1},
      {"Pushto | Pashto", 1}
    ]
  end

  defp get_geographic_origins do
    [
      {"India", 1433},
      {"Sri Lanka", 610},
      {"Pakistan", 561},
      {"Nepal", 240},
      {"Bangladesh", 47},
      {"United States", 36},
      {"Afghanistan", 27},
      {"Maldives", 17},
      {"Bhutan", 14},
      {"United Kingdom", 9},
      {"Switzerland", 5},
      {"India--Delhi", 4},
      {"India--West Bengal", 4},
      {"Italy", 3},
      {"Netherlands", 3},
      {"India--Maharashtra", 2},
      {"India--Punjab", 2},
      {"Japan", 2},
      {"No place, unknown, or undetermined", 2},
      {"Australia", 1},
      {"China", 1},
      {"Denmark", 1},
      {"France", 1},
      {"Germany", 1},
      {"India--Andhra Pradesh", 1},
      {"India--Chhattīsgarh", 1},
      {"India--Jharkhand", 1},
      {"India--Karnataka", 1},
      {"India--Rajasthan", 1},
      {"India--Telangana", 1},
      {"India--Uttar Pradesh", 1},
      {"South Africa", 1},
      {"Tarai (India and Nepal)", 1}
    ]
  end
end
