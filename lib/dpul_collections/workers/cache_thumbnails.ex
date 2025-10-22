defmodule DpulCollections.Workers.CacheThumbnails do
  use Oban.Worker, queue: :cache
  alias DpulCollections.Utilities

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"solr_document" => solr_document}}) do
    if Application.get_env(:dpul_collections, :cache_thumbnails?) do
      cache_images(solr_document)
    end

    :ok
  end

  defp thumbnail_configurations do
    [
      # Small browse thumbnails
      {"square", "100", "100"},
      # Browse and search results thumbnails
      {"square", "350", "350"},
      # Item page thumbnails
      {"square", "350", "465"}
    ]
  end

  defp primary_thumbnail_configuration(item) do
    {"full", "!#{item.primary_thumbnail_width}", "#{item.primary_thumbnail_height}"}
  end

  # Don't attempt to cache deleted records, or collections
  defp cache_images(%{"deleted" => true}), do: :ok
  defp cache_images(%{"resource_type_s" => "collection"}), do: :ok

  defp cache_images(solr_document) do
    item =
      solr_document
      |> Utilities.stringify_map_keys()
      |> DpulCollections.Item.from_solr()

    # Cache top 12 (number of thumbnails on item page).
    # Plus the primary thumbnail.
    tasks =
      item.image_service_urls
      |> Enum.take(12)
      |> List.insert_at(0, item.primary_thumbnail_service_url)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map(fn url -> Task.async(__MODULE__, :cache_iiif_image, [url]) end)

    # Cache larger primary thumbnail image
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
    thumbnail_configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
  end

  def cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "/#{region}/#{width},#{height}/0/default.jpg"

    options =
      [
        base_url: base_url,
        url: url,
        headers: %{"x-cache-iiif-request" => ["true"]}
      ]
      # Add plug option to facilitate http stubbing in tests
      |> Keyword.merge(Application.get_env(:dpul_collections, :thumbnail_req_options, []))

    {:ok, %{status: 200}} = Req.request(options)
  end
end
