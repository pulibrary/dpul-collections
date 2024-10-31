defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :date,
    :page_count,
    :language,
    :url
  ]

  def from_solr(nil), do: nil

  def from_solr(doc) do
    language = doc["detectlang_ss"] |> Enum.at(0)
    title = doc["title_ss"] |> Enum.at(0)
    id = doc["id"]

    %__MODULE__{
      id: id,
      title: title,
      date: doc["display_date_s"],
      page_count: doc["page_count_i"],
      url: generate_url(id, title, language)
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

  defp generate_url(id, title, language) when language in @latin_scripts do
    "/i/#{generate_slug(title)}/item/#{id}"
  end

  defp generate_url(id, _, _) do
    "/item/#{id}"
  end

  defp generate_slug(title) do
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
end
