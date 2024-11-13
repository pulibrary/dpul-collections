defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :date,
    :page_count,
    :url,
    :image_service_urls,
    :description,
    :max_year
  ]

  def from_solr(nil), do: nil

  def from_solr(doc) do
    slug = doc["slug_s"]
    title = doc["title_ss"] |> Enum.at(0)
    id = doc["id"]

    %__MODULE__{
      id: id,
      title: title,
      date: doc["display_date_s"],
      page_count: doc["page_count_i"],
      url: generate_url(id, slug),
      image_service_urls: doc["image_service_urls_ss"] || [],
      description: doc["description_txtm"] || [],
      max_year: doc["max_year_i"] || []
    }
  end

  defp generate_url(id, slug) do
    "/i/#{slug}/item/#{id}"
  end
end
