defmodule SolrTestSupport do
  def mock_solr_documents(count \\ 100) do
    for n <- 1..count do
      date = 2025 - n

      %{
        id: n,
        title_txtm: "Document-#{n}",
        display_date_s: date |> Integer.to_string(),
        years_is: [date]
      }
    end
  end

  # In most tests we can read and write to the same collection,
  # we'll call it the active collection
  def active_collection do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end
end
