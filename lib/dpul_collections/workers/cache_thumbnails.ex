defmodule DpulCollections.Workers.CacheThumbnails do
  use Oban.Worker, queue: :cache
  alias DpulCollections.Utilities

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"solr_document" => solr_document}}) do
    if Application.get_env(:dpul_collections, :cache_thumbnails?) do
      cache_images(solr_document)
    end
  end

  defp thumbnail_configurations do
    [
      # Small browse thumbnails
      {"square", "100", "100"},
      # Browse and search results thumbnails
      {"square", "350", "350"},
      # Item page thumbnails
      {"full", "350", "465"}
    ]
  end

  defp primary_thumbnail_configuration(item) do
    {"full", "!#{item.primary_thumbnail_width}", "#{item.primary_thumbnail_height}"}
  end

  # Don't attempt to cache deleted records
  defp cache_images(%{"deleted" => true}), do: :ok

  defp cache_images(solr_document) do
    item =
      solr_document
      |> Utilities.stringify_map_keys()
      |> DpulCollections.Item.from_solr()

    # Cache standard thumbnails
    tasks =
      item.image_service_urls
      |> Enum.map(fn url -> Task.async(__MODULE__, :cache_iiif_image, [url]) end)

    # Cache primary thumbnail item page image
    primary_thumbnail_task =
      case item.primary_thumbnail_service_url do
        nil ->
          []

        _ ->
          Task.async(__MODULE__, :cache_iiif_image, [
            item.primary_thumbnail_service_url,
            primary_thumbnail_configuration(item)
          ])
          |> List.wrap()
      end

    # Run tasks with 10 minute timeout
    Task.await_many(tasks ++ primary_thumbnail_task, 600_000)

    :ok
  end

  def cache_iiif_image(base_url) do
    thumbnail_configurations()
    |> Enum.map(fn config -> Task.async(__MODULE__, :cache_iiif_image, [base_url, config]) end)
    # 2 minute timeout
    |> Task.await_many(120_000)
  end

  def cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "/#{region}/#{width},#{height}/0/default.jpg"

    options =
      [
        base_url: base_url,
        url: url
      ]
      # Add plug option to facilitate http stubbing in tests
      |> Keyword.merge(Application.get_env(:dpul_collections, :thumbnail_req_options, []))

    {:ok, %{status: 200}} =
      Req.request(options, into: fn {:data, _}, {req, resp} -> {:cont, {req, resp}} end)
  end
end
