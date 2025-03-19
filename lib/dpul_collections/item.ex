defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :alternative_title,
    :date,
    :page_count,
    :url,
    :image_service_urls,
    :primary_thumbnail_service_url,
    :description
  ]

  def metadata_display_fields do
    [
      :date,
      :alternative_title,
      :description
    ]
  end

  def from_solr(nil), do: nil

  def from_solr(doc) do
    slug = doc["slug_s"]
    title = doc["title_ss"] |> Enum.at(0)
    id = doc["id"]

    %__MODULE__{
      id: id,
      title: title,
      alternative_title: doc["alternative_title_txtm"] || [],
      date: doc["display_date_s"],
      page_count: doc["page_count_i"],
      url: generate_url(id, slug),
      image_service_urls: doc["image_service_urls_ss"] || [],
      primary_thumbnail_service_url: doc["primary_thumbnail_service_url_s"],
      description: doc["description_txtm"] || []
    }
  end

  defp generate_url(id, slug) do
    "/i/#{slug}/item/#{id}"
  end
end
