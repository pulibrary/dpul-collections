defmodule DpulCollections.Item do
  alias DpulCollections.Collection
  alias DpulCollectionsWeb.Live.Helpers
  use DpulCollectionsWeb, :verified_routes
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defstruct [
    :id,
    :title,
    :alternative_title,
    :barcode,
    :box_number,
    :collection,
    :content_warning,
    :contributor,
    :creator,
    :description,
    :digitized_at,
    :date,
    :file_count,
    :genre,
    :geo_subject,
    :geographic_origin,
    :folder_number,
    :height,
    :holding_location,
    :iiif_manifest_url,
    :image_canvas_ids,
    :image_service_urls,
    :keywords,
    :language,
    :page_count,
    :primary_thumbnail_service_url,
    :primary_thumbnail_width,
    :primary_thumbnail_height,
    :project,
    :provenance,
    :publisher,
    :rights_statement,
    :series,
    :sort_title,
    :subject,
    :transliterated_title,
    :updated_at,
    :url,
    :pdf_url,
    :width,
    :metadata_url,
    :viewer_url,
    :slug,
    :tagline
  ]

  def metadata_display_fields do
    [
      # {field, field_label}
      {:creator, gettext("Creator of work")},
      {:publisher, gettext("Publisher")},
      {:language, gettext("Language")},
      {:geographic_origin, gettext("Geographic Origin")},
      {:geo_subject, gettext("Geographic Subject")},
      {:subject, gettext("Subject")}
    ]
  end

  # description is handled differently so it's not in this list
  def metadata_detail_categories do
    [
      {gettext("Descriptive Information"),
       [
         {:title, gettext("Title")},
         {:transliterated_title, gettext("Transliterated Title")},
         {:alternative_title, gettext("Alternative Title")},
         {:sort_title, gettext("Sort Title")},
         {:creator, gettext("Creator of work")},
         {:contributor, gettext("Contributor")},
         {:publisher, gettext("Publisher")},
         {:language, gettext("Language")},
         {:date, gettext("Date Created")},
         {:genre, gettext("Genre")},
         {:content_warning, gettext("Content Warning")},
         {:series, gettext("Series")},
         {:provenance, gettext("Provenance")},
         {:rights_statement, gettext("Rights Statement")}
       ]},
      {gettext("Discovery Information"),
       [
         {:subject, gettext("Subject")},
         {:geo_subject, gettext("Geographic Subject")},
         {:keywords, gettext("Keywords")},
         {:geographic_origin, gettext("Geographic Origin")}
       ]},
      {gettext("Physical Characteristics"),
       [
         {:height, gettext("Height")},
         {:width, gettext("Width")},
         {:page_count, gettext("Page Count")},
         {:file_count, gettext("File Count")}
       ]},
      {gettext("Institutional Information"),
       [
         {:project, gettext("Ephemera Project")},
         # :collection,
         {:box_number, gettext("Box number")},
         {:folder_number, gettext("Folder number")},
         {:barcode, gettext("Barcode")},
         {:holding_location, gettext("Holding location")},
         {:iiif_manifest_url, gettext("IIIF Manifest URL")}
       ]}
    ]
  end

  def from_solr(nil), do: nil
  def from_solr(doc = %{"resource_type_s" => "collection"}), do: Collection.from_solr(doc)

  def from_solr(doc) do
    slug = doc["authoritative_slug_s"] || doc["slug_s"]
    id = doc["id"]
    title = Map.get(doc, "title_ss") || Map.get(doc, "title_txtm") || []
    {primary_thumbnail_width, primary_thumbnail_height} = primary_thumbnail_dimensions(doc)

    %__MODULE__{
      id: id,
      title: title,
      slug: slug,
      alternative_title: doc["alternative_title_txtm"] || [],
      barcode: doc["barcode_txtm"] || [],
      box_number: doc["box_number_txtm"] || [],
      collection: [],
      content_warning: doc["content_warning_s"],
      contributor: doc["contributor_txt_sort"] || [],
      creator: doc["creator_txt_sort"] || [],
      date: doc["display_date_s"],
      description: doc["description_txtm"] || [],
      digitized_at: doc["digitized_at_dt"],
      file_count: doc["file_count_i"],
      folder_number: doc["folder_number_txtm"] || [],
      genre: doc["genre_txt_sort"] || [],
      geo_subject: doc["geo_subject_txt_sort"] || [],
      geographic_origin: doc["geographic_origin_txt_sort"] || [],
      height: doc["height_txtm"] || [],
      holding_location: doc["holding_location_txt_sort"] || [],
      iiif_manifest_url: doc["iiif_manifest_url_s"] || [],
      image_canvas_ids: doc["image_canvas_ids_ss"] || [],
      image_service_urls: doc["image_service_urls_ss"] || [],
      keywords: doc["keywords_txt_sort"] || [],
      language: doc["language_txt_sort"] || [],
      page_count: doc["page_count_txtm"] || [],
      primary_thumbnail_service_url: doc["primary_thumbnail_service_url_s"],
      primary_thumbnail_width: primary_thumbnail_width,
      primary_thumbnail_height: primary_thumbnail_height,
      project: doc["ephemera_project_title_s"],
      provenance: doc["provenance_txtm"] || [],
      publisher: doc["publisher_txt_sort"] || [],
      rights_statement: doc["rights_statement_txtm"] || [],
      series: doc["series_txt_sort"] || [],
      sort_title: doc["sort_title_txtm"] || [],
      subject: doc["subject_txt_sort"] || [],
      transliterated_title: doc["transliterated_title_txtm"] || [],
      updated_at: doc["updated_at_dt"],
      url: generate_url(id, slug),
      pdf_url: doc["pdf_url_s"],
      width: doc["width_txtm"] || [],
      metadata_url: generate_metadata_url(id, slug),
      viewer_url: generate_viewer_url(id, slug),
      tagline: doc["tagline_txt_sort"] || []
    }
  end

  defp generate_url(id, slug) do
    "/i/#{slug}/item/#{id}"
  end

  defp generate_metadata_url(id, slug) do
    "/i/#{slug}/item/#{id}/metadata"
  end

  defp generate_viewer_url(id, slug) do
    "/i/#{slug}/item/#{id}/viewer"
  end

  defp primary_thumbnail_dimensions(doc) do
    width = 453
    ratio = doc["primary_thumbnail_h_w_ratio_f"]

    height =
      case ratio do
        nil -> 800
        _ -> (width * ratio) |> round
      end

    {width, height}
  end

  def meta_properties(item = %{title: [title], description: description}) do
    %{
      "og:title" => title,
      "og:description" => meta_description(description),
      "og:image" =>
        "#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg",
      "og:url" => url(~p"/item/#{item.id}")
    }
    |> Helpers.clean_params()
  end

  def meta_properties(_item), do: %{}

  def meta_description([]), do: nil

  def meta_description([description | _rest]) do
    description |> Helpers.truncate(200)
  end
end
