defmodule DpulCollectionsWeb.SearchLive.SearchState do
  use DpulCollections.Solr.Constants
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def from_params(params) do
    %{
      q: params["q"],
      sort_by: valid_sort_by(params),
      page: (params["page"] || "1") |> String.to_integer(),
      per_page: (params["per_page"] || "10") |> String.to_integer(),
      facet: params["facet"] || %{}
    }
  end

  def date_from(%{facet: %{"year" => %{"date_from" => date_from}}}), do: date_from
  def date_from(_), do: nil

  def date_to(%{facet: %{"year" => %{"date_to" => date_to}}}), do: date_to
  def date_to(_), do: nil

  def facet_value(%{facet: %{"year" => date_facets = %{}}}, "year"), do: date_value(date_facets)

  def facet_value(%{facet: facets = %{}}, facet_key) do
    case f = Map.get(facets, facet_key) do
      "" -> nil
      _ -> f
    end
  end

  def date_value(%{"date_from" => date_from, "date_to" => date_to})
      when is_binary(date_to) and is_binary(date_from) and date_from != "" and date_to != "" do
    "#{date_from} #{gettext("to")} #{date_to}"
  end

  def date_value(%{"date_from" => date_from}) when is_binary(date_from) and date_from != "" do
    "#{date_from} #{gettext("to")} #{gettext("Now")}"
  end

  def date_value(%{"date_to" => date_to}) when is_binary(date_to) and date_to != "" do
    "#{gettext("Up")} #{gettext("to")} #{date_to}"
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in @sort_by_keys do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_), do: :relevance
end
