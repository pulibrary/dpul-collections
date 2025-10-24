defmodule DpulCollections.Workers.CacheMosaicImages do
  alias DpulCollectionsWeb.MosaicImages

  use Oban.Worker, queue: :cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    # Cache thumbnails with 10 minute timeout
    MosaicImages.images()
    |> Enum.map(fn url -> Task.async(__MODULE__, :cache_iiif_image, [url]) end)
    |> Task.await_many(600_000)

    :ok
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)

  def cache_iiif_image(image) do
    # Generate iiif image server base url from image tuple
    {_, iiif_url, _} = image

    base_url =
      iiif_url
      |> String.split("/")
      |> Enum.drop(-4)
      |> Enum.join("/")

    MosaicImages.configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
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
      |> Keyword.merge(Application.get_env(:dpul_collections, :mosaic_image_req_options, []))

    {:ok, %{status: 200}} =
      Req.request(options, into: fn {:data, _}, {req, resp} -> {:cont, {req, resp}} end)
  end
end
