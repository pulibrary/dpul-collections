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
    :url,
    genre: ["Digital Collections"],
    categories: [],
    genres: [],
    languages: [],
    geographic_origins: [],
    featured_items: [],
    recently_updated: [],
    contributors: []
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

  def from_solr(nil), do: nil

  def from_solr(doc = %{}) do
    title = Map.get(doc, "title_ss") || Map.get(doc, "title_txtm") || []
    summary = project_summary(title |> hd)

    %__MODULE__{
      id: doc["id"],
      slug: doc["authoritative_slug_s"],
      title: title,
      tagline: doc |> Map.get("tagline_txtm", []) |> Enum.at(0),
      description: doc |> Map.get("description_txtm", []) |> Enum.at(0),
      item_count: summary.count,
      categories: summary.categories,
      genres: summary.genres,
      languages: summary.languages,
      geographic_origins: summary.geographic_origins,
      featured_items: get_featured_items(title |> hd),
      recently_updated: get_recent_items(title |> hd),
      url: "/collections/#{doc["authoritative_slug_s"]}",
      contributors: get_contributors(doc["authoritative_slug_s"])
    }
  end

  def get_contributors("sae") do
    [
      %{
        id: "aisls",
        logo:
          "https://dpul.princeton.edu/uploads/spotlight/attachment/file/587/AILS_Logo_New.png",
        url: "https://www.aisls.org/",
        label: "The American Institute for Sri Lankan Studies (AISLS)",
        description: ~s"""
        <p>The <a href="https://www.aisls.org/">American Institute for Sri Lankan Studies (AISLS)</a> was established in 1996. It is a member of the <a href="http://www.caorc.org/">Council of American Overseas Research Centers (CAORC)</a> and an affiliate of the <a href="http://www.asian-studies.org/">Association for Asian Studies</a>. PUL has collaborated with the AISLS Colombo office, the University of Edinburgh, and the South Asia Open Archives to digitally host "Dissidents and Activists in Sri Lanka, 1960s to 1990s."</p>
        """
      }
    ]
  end

  def get_contributors("lae") do
    [
      %{
        id: "clir",
        logo:
          "https://lae.princeton.edu/assets/CLIR_logo-8c0e18a0823a74ff69d628b3cd226d32d7f6c37a85408023de0c1e38f76df6b8.gif",
        label: "Council on Library and Information Resources",
        url: "https://www.clir.org/",
        description:
          "The Princeton University Digital Archive of Latin American and Caribbean Ephemera is made possible with generous grants from The Council on Library and Information Resources and The Latin Americanist Research Resources Project."
      },
      %{
        id: "larrp",
        logo:
          "https://lae.princeton.edu/assets/larrp-53632ea58cc61411babf45947b707dbc0be401f21ef72a5560aa1ed1192f2ac1.gif",
        label: "Latin Americanist Research Resources Project",
        url: "http://www.crl.edu/programs/larrp",
        description:
          "The Princeton University Digital Archive of Latin American and Caribbean Ephemera is made possible with generous grants from The Council on Library and Information Resources and The Latin Americanist Research Resources Project."
      },
      %{
        id: "dartmouth",
        label: "Dartmouth Libraries",
        logo:
          "https://lae.princeton.edu/assets/dartmouth_logo-9bfe6d626202b0620c409d67646d7691790d0fbc93e60914cb7ac054b39c8db1.png",
        url: "https://www.library.dartmouth.edu/",
        description:
          "Thanks to Dartmouth Libraries for their contributions to Latin American Ephemera."
      }
    ]
  end

  def get_contributors(_), do: []

  defp get_recent_items(label) do
    Solr.recently_updated(5, SearchState.from_params(%{"filter" => %{"project" => label}}))
    |> Map.get("docs")
    |> Enum.map(&Item.from_solr/1)
  end

  defp project_summary(label) do
    summary = Solr.project_summary(label)

    %{
      count: summary.total_items,
      languages: summary.filter_data["language"].data,
      geographic_origins: summary.filter_data["geographic_origin"].data,
      categories: summary.filter_data["category"].data,
      genres: summary.filter_data["genre"].data
    }
  end
end
