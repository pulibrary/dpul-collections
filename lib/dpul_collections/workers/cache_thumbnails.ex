defmodule DpulCollections.Workers.CacheThumbnails do
  use Oban.Worker, queue: :cache
  alias DpulCollections.Utilities

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"solr_document" => %{"deleted" => true}}}) do
    :ok
  end

  def perform(%Oban.Job{args: %{"solr_document" => solr_document}}) do
    item =
      solr_document
      |> Utilities.stringify_map_keys()
      |> DpulCollections.Item.from_solr()

    # Cache standard thumbnails
    item.image_service_urls |> Enum.each(&cache_iiif_image(&1))

    # Cache primary thumbnail item page image
    if item.primary_thumbnail_service_url do
      cache_iiif_image(item.primary_thumbnail_service_url, primary_thumbnail_configuration(item))
    end

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

  defp primary_thumbnail_configuration(item) do
    {"full", "!#{item.primary_thumbnail_width}", "#{item.primary_thumbnail_height}"}
  end

  defp cache_iiif_image(base_url) do
    thumbnail_configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
  end

  defp cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "/#{region}/#{width},#{height}/0/default.jpg"

    options =
      [
        base_url: base_url,
        url: url
      ]
      |> Keyword.merge(Application.get_env(:dpul_collections, :thumbnail_req_options, []))

    {:ok, %{status: 200}} = Req.request(options)
  end
end
