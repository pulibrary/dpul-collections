defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :alternative_title,
    :barcode,
    :box_number,
    :content_warning,
    :contributor,
    :creator,
    :description,
    :date,
    :file_count,
    :folder_number,
    :height,
    :holding_location,
    :image_service_urls,
    :keywords,
    :page_count,
    :primary_thumbnail_service_url,
    :provenance,
    :publisher,
    :rights_statement,
    :series,
    :sort_title,
    :transliterated_title,
    :url,
    :width
  ]

  def metadata_display_fields do
    [
      :date,
      :description,
      :alternative_title,
      :barcode,
      :box_number,
      :content_warning,
      :contributor,
      :creator,
      :folder_number,
      :height,
      :holding_location,
      :keywords,
      :page_count,
      :provenance,
      :publisher,
      :rights_statement,
      :series,
      :transliterated_title,
      :width
    ]
  end

  def from_solr(nil), do: nil

  def from_solr(doc) do
    slug = doc["slug_s"]
    id = doc["id"]
    title = doc["title_ss"] |> Enum.at(0)

    %__MODULE__{
      id: id,
      title: title,
      alternative_title: doc["alternative_title_txtm"] || [],
      barcode: doc["barcode_txtm"] || [],
      box_number: doc["box_number_txtm"] || [],
      content_warning: doc["content_warning_txtm"] || [],
      contributor: doc["contributor_txtm"] || [],
      creator: doc["creator_txtm"] || [],
      date: doc["display_date_s"],
      description: doc["description_txtm"] || [],
      file_count: doc["file_count_i"],
      folder_number: doc["folder_number_txtm"] || [],
      height: doc["height_txtm"] || [],
      holding_location: doc["holding_location_txtm"] || [],
      image_service_urls: doc["image_service_urls_ss"] || [],
      keywords: doc["keywords_txtm"] || [],
      page_count: doc["page_count_txtm"] || [],
      primary_thumbnail_service_url: doc["primary_thumbnail_service_url_s"],
      provenance: doc["provenance_txtm"] || [],
      publisher: doc["publisher_txtm"] || [],
      rights_statement: doc["rights_statement_txtm"] || [],
      series: doc["series_txtm"] || [],
      sort_title: doc["sort_title_txtm"] || [],
      transliterated_title: doc["transliterated_title_txtm"] || [],
      url: generate_url(id, slug),
      width: doc["width_txtm"] || []
    }
  end

  defp generate_url(id, slug) do
    "/i/#{slug}/item/#{id}"
  end
end
