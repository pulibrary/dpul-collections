defmodule DpulCollectionsWeb.SearchLive.SearchState do
  use DpulCollections.Solr.Constants
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def from_params(params) do
    %{
      q: params["q"],
      sort_by: valid_sort_by(params),
      page: (params["page"] || "1") |> String.to_integer(),
      per_page: (params["per_page"] || "50") |> String.to_integer(),
      filter: params["filter"] || %{},
      extra_params: []
    }
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in @sort_by_keys do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_), do: :relevance
end
