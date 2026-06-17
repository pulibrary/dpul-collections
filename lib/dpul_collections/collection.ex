defmodule DpulCollections.Collection do
  alias DpulCollections.Item
  alias DpulCollections.Search.SearchState
  alias DpulCollections.Solr
  use Gettext, backend: DpulCollectionsWeb.Gettext
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :slug,
    :title,
    :tagline,
    :summary,
    :item_count,
    :url,
    :banner_image,
    :banner_image_id,
    :banner_item,
    format: ["Digital Collections"],
    categories: [],
    formats: [],
    languages: [],
    geographic_origins: [],
    featured_items: [],
    recently_added: [],
    related_collections: [],
    contributors: [],
  ]

  def from_slug(slug) do
    Solr.find_by_slug(slug)
    |> from_solr()
  end

  def authoritative_slug_from_title(title) do
    case Solr.find_by_collection_title(title) do
      %{"authoritative_slug_s" => slug} when is_binary(slug) -> slug
      _ -> nil
    end
  end

  def from_solr(nil), do: nil

  def from_solr(doc = %{}) do
    title = Map.get(doc, "title_ss") || Map.get(doc, "title_txtm") || []
    summary = collection_summary(title |> hd)

    %__MODULE__{
      id: doc["id"],
      slug: doc["authoritative_slug_s"],
      title: title,
      tagline: doc |> Map.get("tagline_txtm", []) |> Enum.at(0),
      summary: doc |> Map.get("summary_txtm", []) |> Enum.at(0) |> process_summary(),
      banner_image: doc |> Map.get("banner_image_s"),
      banner_image_id: doc |> Map.get("banner_image_id_s"),
      item_count: summary.count,
      categories: summary.categories,
      formats: summary.formats,
      languages: summary.languages,
      geographic_origins: summary.geographic_origins,
      featured_items: get_featured_items(title |> hd),
      url: "/collections/#{doc["authoritative_slug_s"]}",
      contributors: get_contributors(doc["authoritative_slug_s"])
    }
  end

  def load_related_records(nil), do: nil

  # avoid recursively loading related collections into infinity
  # Since we're here anyway, put everything in that does a query and is only
  # needed on the collection show page
  def load_related_records(collection) do
    updates = [
      banner_item: get_banner_item(collection),
      recently_added: get_recent_items(collection.title |> hd),
      related_collections: get_related_collections(collection.title |> hd)
    ]
    struct!(collection, updates)
  end

  defp get_banner_item(%{banner_image: banner_image, banner_image_id: banner_image_id})
       when is_binary(banner_image) and is_binary(banner_image_id) do
    Solr.find_by_id(banner_image_id) |> Item.from_solr()
  end

  defp get_banner_item(collection) do
    collection.featured_items |> then(&if &1 != [], do: Enum.random(&1))
  end

  def get_related_collections(label) do
    Solr.related_collections(label)
    |> Enum.map(&from_solr/1)
  end

  defp get_featured_items(label) do
    params =
      SearchState.from_params(%{
        "filter" => %{"collection" => label, "featured" => true},
        "per_page" => "4"
      })

    Solr.query(params)["docs"] |> Enum.map(&Item.from_solr/1)
  end

  defp process_summary(nil), do: nil

  defp process_summary(summary) do
    summary
    # Take all <h# tags and replace them with h3
    |> String.replace(~r/<([\/]?)h[0-9]/, "<\\1h3")
    # Get id of <br> - let our page flow handle it.
    |> String.replace("<br>", "")
  end

  def get_contributors("sae") do
    [
      %{
        id: "aisls",
        logo: ~p"/images/sae/AILS_Logo_New.png",
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
        logo: ~p"/images/lae/CLIR_logo.gif",
        label: "Council on Library and Information Resources",
        url: "https://www.clir.org/",
        description:
          "The Princeton University Digital Archive of Latin American and Caribbean Ephemera is made possible with generous grants from The Council on Library and Information Resources and The Latin Americanist Research Resources Project."
      },
      %{
        id: "larrp",
        logo: ~p"/images/lae/larrp.gif",
        label: "Latin Americanist Research Resources Project",
        url: "http://www.crl.edu/programs/larrp",
        description:
          "The Princeton University Digital Archive of Latin American and Caribbean Ephemera is made possible with generous grants from The Council on Library and Information Resources and The Latin Americanist Research Resources Project."
      },
      %{
        id: "dartmouth",
        label: "Dartmouth Libraries",
        logo: ~p"/images/lae/dartmouth_logo.png",
        url: "https://www.library.dartmouth.edu/",
        description:
          "Thanks to Dartmouth Libraries for their contributions to Latin American Ephemera."
      }
    ]
  end

  def get_contributors(_), do: []

  defp get_recent_items(label) do
    Solr.recently_added(5, SearchState.from_params(%{"filter" => %{"collection" => label}}))
    |> Map.get("docs")
    |> Enum.map(&Item.from_solr/1)
  end

  defp collection_summary(label) do
    summary = Solr.collection_summary(label)

    %{
      count: summary.total_items,
      languages: summary.filter_data["language"].data,
      geographic_origins: summary.filter_data["geographic_origin"].data,
      categories: summary.filter_data["category"].data,
      formats: summary.filter_data["format"].data
    }
  end
end
