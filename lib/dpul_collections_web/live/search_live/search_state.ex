defmodule DpulCollectionsWeb.SearchLive.SearchState do
  use DpulCollections.Solr.Constants
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def from_params(params) do
    %{
      q: params["q"],
      sort_by: valid_sort_by(params),
      page: (params["page"] || "1") |> String.to_integer(),
      per_page: (params["per_page"] || "10") |> String.to_integer(),
      date_from: params["date_from"] || nil,
      date_to: params["date_to"] || nil,
      genre: params["genre"] || nil
    }
  end

  def date_value(%{date_from: date_from, date_to: date_to})
      when is_binary(date_to) and is_binary(date_from) do
    "#{date_from} #{gettext("to")} #{date_to}"
  end

  def date_value(%{date_from: date_from}) when is_binary(date_from) do
    "#{date_from} #{gettext("to")} #{gettext("Now")}"
  end

  def date_value(%{date_to: date_to}) when is_binary(date_to) do
    "#{gettext("Up")} #{gettext("to")} #{date_to}"
  end

  def date_value(%{}), do: nil

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in @sort_by_keys do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_), do: :relevance
end
