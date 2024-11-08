defmodule SolrTestSupport do
  def mock_solr_documents(count \\ 100) do
    for n <- 1..count do
      date = 2025 - n
      page_count = Enum.random(1..10)

      %{
        id: n,
        title_txtm: "Document-#{n}",
        display_date_s: date |> Integer.to_string(),
        years_is: [date],
        page_count_i: page_count,
        image_service_urls_ss: [
          "https://example.com/iiif/2/image1",
          "https://example.com/iiif/2/image2"
        ]
      }
    end
  end

  # In most tests we can read and write to the same collection,
  # we'll call it the active collection
  def active_collection do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end
end
