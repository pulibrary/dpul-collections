defmodule DpulCollections.Workers.CacheThumbnails do
  use Oban.Worker, queue: :cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"solr_document" => solr_document}}) do
    item = DpulCollections.Item.from_solr(solr_document)

    # Cache standard thumbnails
    item.image_service_urls |> Enum.each(&cache_iiif_image(&1))

    # Cache primary thumbnail item page image
    cache_iiif_image(item.primary_thumbnail_service_url, primary_thumbnail_configuration(item))
    :ok
  end

  defp thumbnail_configurations do
    [
      {"square", "100", "100"},
      {"square", "350", "350"},
      {"full", "278", ""},
      {"full", "350", "465"}
    ]
  end

  defp hero_image_configurations do
    {"pct:15,15,25,25", "", "200"}
    {"pct:15,30,25,25", "", "200"}
    {"pct:15,45,25,25", "", "200"}
    {"pct:15,60,25,25", "", "200"}
    {"pct:30,15,25,25", "", "200"}
    {"pct:30,30,25,25", "", "200"}
    {"pct:30,45,25,25", "", "200"}
    {"pct:30,60,25,25", "", "200"}
    {"pct:45,15,25,25", "", "200"}
    {"pct:45,30,25,25", "", "200"}
    {"pct:45,45,25,25", "", "200"}
    {"pct:45,60,25,25", "", "200"}
    {"pct:60,15,25,25", "", "200"}
    {"pct:60,30,25,25", "", "200"}
    {"pct:60,45,25,25", "", "200"}
    {"pct:60,60,25,25", "", "200"}
  end

  defp primary_thumbnail_configuration(item) do
    {"full", "!#{item.primary_thumbnail_width}", "#{item.primary_thumbnail_height}"}
  end

  defp cache_iiif_image(base_url) do
    thumbnail_configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
  end

  defp cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "#{base_url}/#{region}/#{width},#{height}/0/default.jpg"
  end
end
