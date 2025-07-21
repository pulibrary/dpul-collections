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
          solr_param: "updated_at_dt desc",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Recently Updated")
        }
      }
      @sort_by_keys Enum.map(Map.keys(@valid_sort_by), &to_string/1)

      @filters %{
        "contributor" => %{
          solr_field: "contributor_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Contributor"),
          value_function: &Function.identity/1
        },
        "creator" => %{
          solr_field: "creator_txtm",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Creator of work"),
          value_function: &Function.identity/1
        },
        "date" => %{
          solr_field: "display_date_s",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Date Created"),
          value_function: &Function.identity/1
        },
        "genre" => %{
          solr_field: "genre_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Genre"),
          # Identity just returns whatever you gave it.
          value_function: &Function.identity/1
        },
        "geo_subject" => %{
          solr_field: "geo_subject_txtm",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Geographic Subject"),
          value_function: &Function.identity/1
        },
        "geographic_origin" => %{
          solr_field: "geographic_origin_txtm",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Geographic Origin"),
          value_function: &Function.identity/1
        },
        "language" => %{
          solr_field: "language_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Language"),
          value_function: &Function.identity/1
        },
        "project" => %{
          solr_field: "ephemera_project_title_s",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Ephemera Project"),
          # Identity just returns whatever you gave it.
          value_function: &Function.identity/1
        },
        "publisher" => %{
          solr_field: "publisher_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Publisher"),
          value_function: &Function.identity/1
        },
        "rights_statement" => %{
          solr_field: "rights_statement_txtm",
          label:
            Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Rights Statement"),
          value_function: &Function.identity/1
        },
        "similar" => %{
          solr_field: "none",
          label: "Similar To",
          value_function: &DpulCollections.Solr.Constants.id_to_title/1
        },
        "subject" => %{
          solr_field: "subject_txtm",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Subject"),
          value_function: &Function.identity/1
        },
        "year" => %{
          solr_field: "years_is",
          label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year"),
          value_function: &DpulCollections.Solr.Constants.date_value/1
        }
      }

      @filter_keys Map.keys(@filters)
    end
  end

  def id_to_title(nil), do: nil

  def id_to_title(id) do
    DpulCollections.Solr.find_by_id(id) |> DpulCollections.Item.from_solr() |> Map.get(:title)
  end

  # Returns a string version of a date facet.
  def date_value(year_params = %{}) do
    from = year_params["from"] || gettext("Up")
    to = year_params["to"] || gettext("Now")
    "#{from} #{gettext("to")} #{to}"
  end

  def date_value(_), do: nil
end
