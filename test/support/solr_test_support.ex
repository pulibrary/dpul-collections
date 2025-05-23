defmodule SolrTestSupport do
  def mock_solr_documents(count \\ 100) do
    for n <- 1..count do
      date = 2025 - n

      # Equals the number of image service urls
      file_count = 7

      # Assign thumbnail urls to even numbered documents.
      # Used for testing thumbnail rendering order
      thumbnail_url =
        cond do
          rem(n, 2) == 0 -> "https://example.com/iiif/2/image2"
          true -> nil
        end

      # Even numbered documents are folders.
      genre =
        cond do
          rem(n, 2) == 0 -> ["Folders"]
          true -> ["Pamphlets"]
        end

      %{
        id: n,
        title_txtm: "Document-#{n}",
        display_date_s: date |> Integer.to_string(),
        years_is: [date],
        file_count_i: file_count,
        image_service_urls_ss: [
          "https://example.com/iiif/2/image1",
          "https://example.com/iiif/2/image2",
          "https://example.com/iiif/2/image3",
          "https://example.com/iiif/2/image4",
          "https://example.com/iiif/2/image5",
          "https://example.com/iiif/2/image6",
          "https://example.com/iiif/2/image7"
        ],
        genre_txtm: genre,
        primary_thumbnail_service_url_s: thumbnail_url,
        digitized_at_dt:
          DateTime.utc_now() |> DateTime.add(-100 + 1 * n, :day) |> DateTime.to_iso8601()
      }
    end
  end

  # In most tests we can read and write to the same collection,
  # we'll call it the active collection
  def active_collection do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end
end
