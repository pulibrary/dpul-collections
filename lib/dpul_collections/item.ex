defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :date,
    :page_count,
    :language,
    :slug
  ]

  def from_solr(nil, _), do: nil

  def from_solr(doc, :item_page) do
    language = doc["detectlang_ss"] |> Enum.at(0)
    title = doc["title_ss"] |> Enum.at(0)

    %__MODULE__{
      id: doc["id"],
      title: title,
      date: doc["display_date_s"],
      page_count: doc["page_count_i"],
      language: language,
      slug: generate_slug(title, language)
    }
  end

  def from_solr(doc, :search_page) do
    title = doc["title_ss"] |> Enum.at(0)

    %__MODULE__{
      id: doc["id"],
      title: title,
      date: doc["display_date_s"],
      page_count: doc["page_count_i"]
    }
  end

  @latin_scripts [
    "ca",
    "cz",
    "da",
    "de",
    "en",
    "es",
    "et",
    "eu",
    "fi",
    "fr",
    "ga",
    "gl",
    "hu",
    "id",
    "it",
    "lv",
    "nl",
    "no",
    "pt",
    "ro",
    "sv",
    "tr"
  ]

  defp generate_slug(title, language) when language in @latin_scripts do
    punctuation = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    regex = "[" <> Regex.escape("-") <> Regex.escape(punctuation) <> "[:space:]]"
    separator = "-"
    max_words = 4

    title
    |> String.split(Regex.compile!(regex), trim: true)
    |> Enum.filter(&(&1 != ""))
    |> Enum.take(max_words)
    |> Enum.join(separator)
    |> String.downcase()
  end

  defp generate_slug(_, _), do: nil
end
