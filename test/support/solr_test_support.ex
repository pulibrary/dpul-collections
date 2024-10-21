defmodule SolrTestSupport do
  def mock_solr_documents(count \\ 100) do
    for n <- 1..count do
      date = 2025 - n

      %{
        id: n,
        title_ss: "Document: #{n}",
        display_date_s: date |> Integer.to_string(),
        years_is: [date]
      }
    end
  end
end
