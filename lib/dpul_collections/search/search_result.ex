defmodule DpulCollections.Search.SearchResult do
  use DpulCollections.Solr.Constants
  alias DpulCollections.Item
  defstruct [:results, :total_items, :filter_data, spelling_suggestions: []]
  @type filter_key :: String.t()
  @type filter_value :: String.t()
  @type filter_count :: integer()
  @type filter_value_datum :: {filter_value, filter_count}

  def from_solr(solr_response = %{"facet_counts" => facet_counts, "response" => response}) do
    %__MODULE__{
      results: response["docs"] |> Enum.map(&Item.from_solr/1) |> Enum.map(&Item.with_parent/1),
      total_items: response["numFound"],
      filter_data: facets_to_filter_data(extract_facets(facet_counts)),
      spelling_suggestions: extract_collations(solr_response["spellcheck"])
    }
  end

  # Solr returns every collation as two entries, "collation" and then the map
  # that is the collation, so we gotta group 'em up if there's more than one
  # collation.
  # ["collation", %{"collationQuery" => "political poster", "hits" => 3, ...}, ...]
  defp extract_collations(%{"collations" => collations}) do
    collations
    |> Enum.chunk_every(2)
    |> Enum.map(fn [_, %{"collationQuery" => query, "hits" => hits}] -> {query, hits} end)
    # Sometimes two collations have the same hits because of stemming, so just
    # dedupe them for now so it doesn't recommend "government" and "governments"
    |> Enum.uniq_by(fn {_query, hits} -> hits end)
  end

  defp extract_collations(_), do: []

  @spec facets_to_filter_data(%{filter_key => [filter_value_datum]}) :: %{
          filter_key => %{label: filter_label :: String.t(), data: [filter_value_datum]}
        }
  defp facets_to_filter_data(facet_map) do
    facet_map
    |> Enum.map(fn {facet_key, facet_data} ->
      {facet_key,
       %{
         label: @filters[facet_key].label,
         data: facet_data
       }}
    end)
    |> Map.new()
  end

  @spec extract_facets(%{
          String.t() => %{
            filter_key() => [filter_value() | filter_count()]
          }
        }) :: %{filter_key() => [filter_value_datum()]}
  defp extract_facets(%{"facet_fields" => facet_fields}) do
    # facet_fields looks like %{"field" => ["Value 1", count, "Value 2", count]}
    facet_fields
    |> Enum.map(fn {field, field_values} ->
      {
        field,
        # Split into pairs
        Enum.chunk_every(field_values, 2)
        # Convert sub-lists to tuples
        |> Enum.map(&List.to_tuple/1)
      }
    end)
    |> Map.new()
  end
end
