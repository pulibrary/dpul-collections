defmodule DpulCollections.Solr.Constants do
  defmacro __using__(_) do
    quote do
      # List of valid sort_by, keys are URL params in DPUL-C, values are solr params.
      require Gettext.Macros
      @valid_sort_by %{
        relevance:  %{solr_param: "score desc", label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Relevance")},
        date_desc: %{solr_param: "years_is desc", label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year (newest first)")},
        date_asc: %{solr_param: "years_is asc", label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Year (oldest first)")},
        recently_added: %{solr_param: "digitized_at_dt desc", label: Gettext.Macros.gettext_with_backend(DpulCollectionsWeb.Gettext, "Recently Added")}
      }
      @sort_by_keys Enum.map(Map.keys(@valid_sort_by), &to_string/1)
    end
  end
end
