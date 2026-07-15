defmodule DpulCollections.Workers.CacheThumbnails do
  use Oban.Worker, queue: :cache
  alias DpulCollections.IIIF
  alias DpulCollections.Utilities
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"solr_document" => solr_document}}) do
    if Application.get_env(:dpul_collections, :cache_thumbnails?) do
      cache_images(solr_document)
    end

    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)

  defp thumbnail_configurations do
    [
      IIIF.small_browse_thumbnail_parameters(),
      IIIF.result_thumbnail_parameters(),
      IIIF.primary_search_thumbnail_parameters(),
      IIIF.item_thumbnail_parameters(),
      IIIF.clover_thumbnail_parameters()
    ]
  end

  defp primary_thumbnail_configuration(item) do
    IIIF.primary_thumbnail_parameters(item.primary_thumbnail_width, item.primary_thumbnail_height)
  end

  # Don't attempt to cache deleted records, or collections
  defp cache_images(%{"deleted" => true}), do: :ok

  defp cache_images(solr_document = %{"resource_type_s" => "collection", "banner_image_s" => url})
       when is_binary(url) do
    collection =
      solr_document
      |> DpulCollections.Collection.from_solr()

    task = Task.async(__MODULE__, :cache_iiif_image, [collection.banner_image])

    # Run task with 10 minute timeout
    Task.await(task, 600_000)

    :ok
  end

  defp cache_images(%{"id" => id, "resource_type_s" => "collection"}) do
    Logger.info("Collection does not have a banner image: #{id}")
    :ok
  end

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
      |> Enum.map(fn url -> Task.async(__MODULE__, :cache_iiif_item_image, [url]) end)

    # Cache larger primary thumbnail image
    primary_thumbnail_task =
      case item.primary_thumbnail_service_url do
        nil ->
          []

        _ ->
          Task.async(__MODULE__, :cache_iiif_item_image, [
            item.primary_thumbnail_service_url,
            primary_thumbnail_configuration(item)
          ])
          |> List.wrap()
      end

    # Run tasks with 10 minute timeout
    Task.await_many(tasks ++ primary_thumbnail_task, 600_000)

    :ok
  end

  def cache_iiif_item_image(base_url) do
    thumbnail_configurations() |> Enum.each(&cache_iiif_item_image(base_url, &1))
  end

  def cache_iiif_item_image(base_url, parameters) do
    cache_iiif_image("#{base_url}/#{parameters}")
  end

  def cache_iiif_image(url) when is_binary(url) do
    options =
      [
        url: url,
        headers: %{"x-cache-iiif-request" => ["true"]}
      ]
      # Add plug option to facilitate http stubbing in tests
      |> Keyword.merge(Application.get_env(:dpul_collections, :thumbnail_req_options, []))

    {:ok, %{status: 200}} = Req.request(options)
  end
end
