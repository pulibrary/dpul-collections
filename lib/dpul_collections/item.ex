defmodule DpulCollections.Item do
  use DpulCollectionsWeb, :verified_routes

  defstruct [
    :id,
    :title,
    :date,
    :page_count,
    :url
  ]

  def from_solr(nil), do: nil

  def from_solr(doc) do
    slug = doc["slug_s"]
    title = doc["title_ss"] |> Enum.at(0)
    id = doc["id"]

    %__MODULE__{
      id: id,
      title: title,
      date: doc["display_date_s"],
      page_count: doc["page_count_i"],
      url: generate_url(id, slug)
    }
  end

  defp generate_url(id, slug) do
    "/i/#{slug}/item/#{id}"
  end
end
