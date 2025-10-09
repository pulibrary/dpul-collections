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

  def remove_filter_value(search_state = %{filter: filters}, filter, value)
      when is_map_key(filters, filter) do
    cond do
      # There's a list, make sure the given value is gone and return the state
      # without it.
      is_list(filters[filter]) ->
        search_state
        |> put_in([:filter, filter], List.delete(filters[filter], value))

      true ->
        search_state
        |> pop_in([:filter, filter])
        |> elem(1)
    end
  end

  def remove_filter_value(search_state, _, _) do
    search_state
  end

  def set_filter(search_state, filter, value) do
    search_state
    |> put_in([:filter, filter], value)
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in @sort_by_keys do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_), do: :relevance
end
