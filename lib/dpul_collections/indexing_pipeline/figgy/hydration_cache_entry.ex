defmodule DpulCollections.IndexingPipeline.Figgy.HydrationCacheEntry do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  schema "figgy_hydration_cache_entries" do
    field :data, :map
    field :related_data, :map, default: %{}
    field :cache_version, :integer
    field :record_id, :string
    field :source_cache_order, :utc_datetime_usec

    timestamps(updated_at: :cache_order, inserted_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(hydration_cache_entry, attrs) do
    hydration_cache_entry
    |> cast(attrs, [:data, :related_data, :cache_version, :record_id, :source_cache_order])
    |> validate_required([:data, :cache_version, :record_id, :source_cache_order])
  end

  @spec to_solr_document(%__MODULE__{}) :: %{}
  def to_solr_document(%{
        record_id: id,
        data: %{
          "metadata" => %{"deleted" => true}
        }
      }) do
    # Generate a small json document for deleted resources that indicates that
    # the Solr record with that id should be deleted from the index.
    %{
      id: id,
      deleted: true
    }
  end

  def to_solr_document(%{
        record_id: id,
        data: data = %{"metadata" => metadata},
        related_data: related_data
      }) do
    parent_metadata = extract_parent_metadata(metadata, related_data)

    %{
      id: id,
      title_txtm: extract_title(metadata),
      alternative_title_txtm: get_in(metadata, ["alternative_title"]),
      barcode_txtm: get_in(metadata, ["barcode"]),
      box_number_txtm: get_in(parent_metadata, ["box_number"]),
      content_warning_txtm: get_in(metadata, ["content_warning"]) |> remove_empty_strings,
      contributor_txtm: get_in(metadata, ["contributor"]),
      creator_txtm: get_in(metadata, ["creator"]),
      description_txtm: get_in(metadata, ["description"]),
      digitized_at_dt: digitized_date(data),
      display_date_s: format_date(metadata),
      ephemera_project_title_s: extract_project_title(related_data),
      file_count_i: file_count(metadata),
      folder_number_txtm: get_in(metadata, ["folder_number"]),
      genre_txtm: extract_term("genre", metadata, related_data),
      geo_subject_txtm: extract_term("geo_subject", metadata, related_data),
      geographic_origin_txtm: extract_term("geographic_origin", metadata, related_data),
      height_txtm: get_in(metadata, ["height"]),
      holding_location_txtm: get_in(metadata, ["holding_location"]),
      iiif_manifest_url_s: iiif_manifest_url(id),
      image_service_urls_ss: image_service_urls(metadata, related_data),
      keywords_txtm: get_in(metadata, ["keywords"]),
      language_txtm: extract_term("language", metadata, related_data),
      page_count_txtm: get_in(metadata, ["page_count"]),
      primary_thumbnail_service_url_s: primary_thumbnail_service_url(metadata, related_data),
      provenance_txtm: get_in(metadata, ["provenance"]),
      publisher_txtm: get_in(metadata, ["publisher"]),
      rights_statement_txtm: extract_rights_statement(metadata),
      series_txtm: get_in(metadata, ["series"]),
      subject_txtm: extract_term("subject", metadata, related_data),
      sort_title_txtm: get_in(metadata, ["sort_title"]),
      transliterated_title_txtm: get_in(metadata, ["transliterated_title"]),
      width_txtm: get_in(metadata, ["width"]),
      years_is: extract_years(data)
    }
  end

  # Remove empty strings from list
  defp remove_empty_strings(field_value) when is_list(field_value) do
    field_value |> Enum.reject(fn v -> v == "" end)
  end

  defp remove_empty_strings(_), do: nil

  defp digitized_date(%{"created_at" => created_at}) when is_binary(created_at) do
    created_at
  end

  defp digitized_date(_data), do: nil

  defp primary_thumbnail_service_url(
         %{"thumbnail_id" => thumbnail_id} = metadata,
         %{"resources" => resources} = related_data
       )
       when is_list(thumbnail_id) do
    thumbnail_member =
      thumbnail_id
      |> Enum.at(0, %{})
      |> Map.get("id")
      |> then(fn id -> resources[id] end)

    if is_nil(thumbnail_member) do
      # When thumbnail id does not correspond to a related FileSet,
      # use the first image service url
      image_service_urls(metadata, related_data)
      |> Enum.at(0)
    else
      extract_service_url(thumbnail_member)
    end
  end

  defp primary_thumbnail_service_url(metadata, related_data) do
    # When the thumbnail id is not set, use first image service url
    image_service_urls(metadata, related_data)
    |> Enum.at(0)
  end

  defp image_service_urls(%{"member_ids" => member_ids}, related_data) do
    member_ids
    |> Enum.map(&extract_service_url(&1, related_data))
    |> Enum.filter(fn url -> url end)
  end

  defp image_service_urls(_, _), do: []

  defp iiif_manifest_url(id) do
    "https://figgy.princeton.edu/concern/ephemera_folders/#{id}/manifest"
  end

  # Find the given member ID in the related data.
  defp extract_service_url(%{"id" => id}, %{"resources" => resources}) do
    extract_service_url(resources[id])
  end

  defp extract_service_url(_id, _), do: nil

  # Find the derivative FileMetadata
  defp extract_service_url(%{
         "internal_resource" => "FileSet",
         "metadata" => %{"file_metadata" => metadata}
       }) do
    derivative_file_metadata = metadata |> Enum.find(&is_derivative/1)
    extract_service_url(derivative_file_metadata)
  end

  # Extract the FileMetadata ID
  defp extract_service_url(%{
         "internal_resource" => "FileMetadata",
         "id" => %{"id" => file_metadata_id}
       }) do
    extract_service_url(file_metadata_id)
  end

  # Convert FileMetadata ID to to a URL using binary pattern matching, which is
  # very fast.
  defp extract_service_url(
         full_id =
           <<first_two::binary-size(2), second_two::binary-size(2), third_two::binary-size(2),
             _rest::binary>>
       ) do
    uuid_path =
      [first_two, second_two, third_two, String.replace(full_id, "-", ""), "intermediate_file"]
      |> Enum.join("%2F")

    "https://iiif-cloud.princeton.edu/iiif/2/#{uuid_path}"
  end

  defp extract_service_url(nil), do: nil

  defp extract_parent_metadata(%{"cached_parent_id" => [%{"id" => cached_parent_id}]}, %{
         "parent_ids" => parent_data
       }) do
    parent_data
    |> get_in([cached_parent_id])
    |> get_in(["metadata"])
  end

  defp extract_parent_metadata(_, _) do
    %{}
  end

  defp extract_term(name, metadata, %{"resources" => resources}) do
    extract_term(get_in(metadata, [name]), resources)
  end

  defp extract_term(_, _, _) do
    nil
  end

  defp extract_term(values, resources) when is_list(values) do
    values
    |> Enum.map(&extract_id_from_map/1)
    |> Enum.map(fn id -> id end)
    |> Enum.map(fn id -> resources[id] end)
    |> Enum.filter(fn resource -> resource end)
    |> Enum.map(&extract_term_label/1)
    |> Enum.filter(fn label -> label end)
  end

  defp extract_term(_, _) do
    nil
  end

  defp extract_id_from_map(%{"id" => id}), do: id

  defp extract_id_from_map(_), do: nil

  defp extract_term_label(%{"metadata" => %{"label" => [label]}}), do: label

  defp extract_term_label(_), do: nil

  defp extract_title(%{"title" => []}) do
    ["[Missing Title]"]
  end

  defp extract_title(%{"title" => title}), do: title

  defp extract_project_title(%{"ancestors" => ancestors}) when map_size(ancestors) > 0 do
    project =
      ancestors
      # Enum converts k,v pairs into tuples
      |> Enum.find(fn a ->
        # Get the resource map from the second element (value) of the tuple
        elem(a, 1)
        |> Map.get("internal_resource") == "EphemeraProject"
      end)

    cond do
      is_nil(project) ->
        nil

      true ->
        project
        |> elem(1)
        |> get_in(["metadata", "title"])
        |> Enum.at(0)
    end
  end

  defp extract_project_title(_), do: nil

  defp extract_rights_statement(%{"rights_statement" => [%{"@id" => url}]}) when is_binary(url) do
    %{
      "http://rightsstatements.org/vocab/CNE/1.0/" => "Copyright Not Evaluated",
      "http://rightsstatements.org/vocab/InC/1.0/" => "In Copyright",
      "http://rightsstatements.org/vocab/InC-RUU/1.0/" =>
        "In Copyright - Rights-holder(s) Unlocatable or Unidentifiable",
      "http://rightsstatements.org/vocab/InC-EDU/1.0/" =>
        "In Copyright - Educational Use Permitted",
      "http://rightsstatements.org/vocab/InC-NC/1.0/" =>
        "In Copyright - NonCommercial Use Permitted",
      "http://rightsstatements.org/vocab/NoC-CR/1.0/" =>
        "No Copyright - Contractual Restrictions",
      "http://rightsstatements.org/vocab/NoC-OKLR/1.0/" =>
        "No Copyright - Other Known Legal Restrictions",
      "http://rightsstatements.org/vocab/NKC/1.0/" => "No Known Copyright",
      "http://cicognara.org/microfiche_copyright" =>
        "This title is reproduced by permission of the Vatican Library",
      "https://www.mfa.org/collections/mfa-images/licensing/frequently-asked-questions" =>
        "Digitized by the Museum of Fine Arts, Boston",
      "https://creativecommons.org/licenses/by/4.0/" => "CC-BY 4.0",
      "https://creativecommons.org/licenses/by-nc-sa/4.0/" =>
        "CC-BY-NonCommercial-ShareAlike 4.0",
      "https://creativecommons.org/licenses/by-nc-nd/4.0/" =>
        "CC-BY-NonCommercial-NoDerivatives 4.0",
      "https://creativecommons.org/publicdomain/zero/1.0/" => "CC-Zero / Public Domain",
      "https://creativecommons.org/publicdomain/mark/1.0/" => "Public Domain Mark"
    }
    |> get_in([url])
    |> List.wrap()
  end

  defp extract_rights_statement(_), do: nil

  defp is_derivative(%{
         "mime_type" => ["image/tiff"],
         "use" => [%{"@id" => "http://pcdm.org/use#ServiceFile"}]
       }),
       do: true

  defp is_derivative(_), do: false

  defp file_count(%{"member_ids" => member_ids}) when is_list(member_ids) do
    member_ids |> length
  end

  defp file_count(_) do
    0
  end

  defp extract_years(%{
         "metadata" => %{"date_range" => [%{"start" => [start_year], "end" => [end_year]}]}
       }) do
    Enum.to_list(String.to_integer(start_year)..String.to_integer(end_year))
  end

  defp extract_years(%{"metadata" => %{"date_created" => []}}) do
    nil
  end

  # This will be single value from figgy, stored as an array.
  # If somehow we get more than 1 value, just take the first
  # It goes into a multi-valued index field, so keep it looking that way
  defp extract_years(%{"metadata" => %{"date_created" => [date | _tail]}, "id" => id}) do
    result = extract_year(date) |> year_string_to_integer()

    case result do
      :error ->
        Logger.warning("couldn't parse date \"#{date}\" for record #{id}")
        nil

      {extracted_date, _rest} ->
        [extracted_date]
    end
  end

  defp extract_years(%{}) do
    # there's no date_created value
    nil
  end

  # Apply regexes to date string and return the first
  # year value that matches. If none match, return nil.
  defp extract_year(date) do
    [
      # "29 Raḥab al-Marjab 1321- [July 1923]"
      # "[1931]"
      # "September [1931]"
      ~r/(\d+)(?=\])/,
      # "November 1952" or "1943"
      ~r/\d{4}/
    ]
    |> Enum.map(fn regex -> Regex.run(regex, date, capture: :first) end)
    |> Enum.find([nil], fn year -> year != nil end)
    |> hd
  end

  defp format_date(%{
         "date_range" => [%{"start" => [start_year], "end" => [end_year], "approximate" => "1"}]
       }) do
    "#{start_year} - #{end_year} (approximate)"
  end

  defp format_date(%{"date_range" => [%{"start" => [start_year], "end" => [end_year]}]}) do
    "#{start_year} - #{end_year}"
  end

  defp format_date(%{"date_created" => [date | _tail]}) do
    date
  end

  defp format_date(%{"date_created" => []}) do
    nil
  end

  defp format_date(%{}) do
    # there's no date_created value
    nil
  end

  defp year_string_to_integer(nil), do: :error

  defp year_string_to_integer(year) do
    Integer.parse(year)
  end
end
