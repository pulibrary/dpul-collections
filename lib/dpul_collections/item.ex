defmodule DpulCollections.Item do
  alias DpulCollections.Collection
  alias DpulCollectionsWeb.Live.Helpers
  alias DpulCollections.IndexingPipeline.Figgy
  require Figgy.ImportedCatalogSchema
  use DpulCollectionsWeb, :verified_routes
  use Gettext, backend: DpulCollectionsWeb.Gettext

  # All Figgy Schema fields.
  defstruct [
              :id,
              :barcode,
              :box_number,
              :call_number,
              :collections,
              :collection_ids,
              :content_warning,
              :summary,
              :digitized_at,
              :file_count,
              :format,
              :folder_number,
              :height,
              :iiif_manifest_url,
              :image_canvas_ids,
              :image_service_urls,
              :keywords,
              :page_count,
              :primary_thumbnail_service_url,
              :primary_thumbnail_width,
              :primary_thumbnail_height,
              :series,
              :transliterated_title,
              :updated_at,
              :url,
              :pdf_url,
              :width,
              :metadata_url,
              :viewer_url,
              :notes,
              :related_name
            ] ++ Figgy.ImportedCatalogSchema.descriptive_attributes() ++ Figgy.ImportedCatalogSchema.marc_relators()

  def metadata_display_fields do
    [
      # {field, field_label}
      {:call_number, gettext("Call Number")},
      {:creator, gettext("Creator of work")},
      {:publisher, gettext("Publisher")},
      {:people,
       {
         gettext("People"),
         [
           {:author, gettext("Author")}
         ]
       }},
      {:language, gettext("Language")},
      {:geographic_origin, gettext("Geographic Origin")},
      {:geo_subject, gettext("Geographic Subject")},
      {:subject, gettext("Subject")}
    ]
  end

  # summary is handled differently so it's not in this list
  def metadata_detail_categories do
    [
      {gettext("Descriptive Information"),
       [
         {:title, gettext("Title")},
         {:transliterated_title, gettext("Transliterated Title")},
         {:alternative_title, gettext("Alternative Title")},
         {:sort_title, gettext("Sort Title")},
         {:call_number, gettext("Call Number")},
         {:identifier, gettext("Identifier")},
         {:creator, gettext("Creator of work")},
         {:contributor, gettext("Contributor")},
         {:publisher, gettext("Publisher")},
         {:language, gettext("Language")},
         {:date, gettext("Date Created")},
         {:format, gettext("Format")},
         {:extent, gettext("Extent")},
         {:content_warning, gettext("Content Warning")},
         {:series, gettext("Series")},
         {:provenance, gettext("Provenance")},
         {:source_acquisition, gettext("Source Acquisition")},
         {:references, gettext("References")},
         {:rights_statement, gettext("Rights Statement")},
         {:notes, gettext("Notes")},
         {:binding_note, gettext("Binding Note")}
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
         {:collections, gettext("Collection")},
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
    slug = doc["slug_s"]
    id = doc["id"]
    title = Map.get(doc, "title_ss") || Map.get(doc, "title_txtm") || []
    {primary_thumbnail_width, primary_thumbnail_height} = primary_thumbnail_dimensions(doc)

    %__MODULE__{
      id: id,
      title: title,
      alternative_title: doc["alternative_title_txtm"] || [],
      identifier: doc["identifier_txt_sort"] || [],
      barcode: doc["barcode_txtm"] || [],
      box_number: doc["box_number_txtm"] || [],
      content_warning: doc["content_warning_s"],
      contributor: doc["contributor_txt_sort"] || [],
      creator: doc["creator_txt_sort"] || [],
      date: doc["display_date_s"],
      summary: doc["summary_txtm"] || [],
      digitized_at: doc["digitized_at_dt"],
      file_count: doc["file_count_i"],
      folder_number: doc["folder_number_txtm"] || [],
      format: (doc["format_txt_sort"] || []) |> List.first(),
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
      collections: doc["collection_titles_ss"] || [],
      collection_ids: doc["collection_ids_ss"] || [],
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
      # ScannedResource specific
      references: doc["references_ss"],
      extent: doc["extent_ss"],
      binding_note: doc["binding_note_ss"],
      source_acquisition: doc["source_acquisition_ss"],
      call_number: doc["call_number_ss"],
      notes: doc["notes_ss"],
      author: doc["author_txt_sort"]
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

  def meta_properties(item = %{title: [title | _], summary: summary}) do
    %{
      "og:title" => title,
      "og:description" => meta_description(summary),
      "og:image" =>
        "#{item.primary_thumbnail_service_url}/full/!#{item.primary_thumbnail_width},#{item.primary_thumbnail_height}/0/default.jpg",
      "og:url" => url(~p"/item/#{item.id}")
    }
    |> Helpers.clean_params()
  end

  def meta_description([]), do: nil

  def meta_description([summary | _rest]) do
    summary |> Helpers.truncate(200)
  end

  def null_item() do
    %__MODULE__{
      id: "null_item",
      content_warning: nil,
      file_count: 0
    }
  end
end
