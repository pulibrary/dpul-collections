defmodule DpulCollections.Solr.Constants do
  use Gettext, backend: DpulCollectionsWeb.Gettext

  defmacro __using__(_) do
    quote do
      # List of valid sort_by, keys are URL params in DPUL-C, values are solr params.
      require Gettext.Macros

      @valid_sort_by %{
        relevance: %{
          solr_param: "score desc",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Relevance")
        },
        date_desc: %{
          solr_param: "years_is desc",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year (newest first)")
        },
        date_asc: %{
          solr_param: "years_is asc",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year (oldest first)")
        },
        recently_added: %{
          solr_param: "digitized_at_dt desc",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Recently Added")
        }
      }
      @sort_by_keys Enum.map(Map.keys(@valid_sort_by), &to_string/1)

      @facets %{
        "year" => %{
          solr_field: "years_is",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year"),
          value_function: &DpulCollections.Solr.Constants.date_value/1
        },
        "genre" => %{
          solr_field: "genre_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Genre"),
          # Identity just returns whatever you gave it.
          value_function: &Function.identity/1
        }
      }

      @facet_keys Map.keys(@facets)
    end
  end

  # Returns a string version of a date facet.
  def date_value(year_params = %{}) do
    from = year_params["from"] || gettext("Up")
    to = year_params["to"] || gettext("Now")
    "#{from} #{gettext("to")} #{to}"
  end

  def date_value(_), do: nil
end
