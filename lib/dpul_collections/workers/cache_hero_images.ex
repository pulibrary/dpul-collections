defmodule DpulCollections.Workers.CacheHeroImages do
  use Oban.Worker, queue: :cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    # Cache hero thumbnails
    DpulCollectionsWeb.HomeLive.hero_images() |> Enum.each(&cache_iiif_image(&1))

    :ok
  end

  defp hero_image_configurations do
    [
      {"pct:15,15,25,25", "", "200"},
      {"pct:15,30,25,25", "", "200"},
      {"pct:15,45,25,25", "", "200"},
      {"pct:15,60,25,25", "", "200"},
      {"pct:30,15,25,25", "", "200"},
      {"pct:30,30,25,25", "", "200"},
      {"pct:30,45,25,25", "", "200"},
      {"pct:30,60,25,25", "", "200"},
      {"pct:45,15,25,25", "", "200"},
      {"pct:45,30,25,25", "", "200"},
      {"pct:45,45,25,25", "", "200"},
      {"pct:45,60,25,25", "", "200"},
      {"pct:60,15,25,25", "", "200"},
      {"pct:60,30,25,25", "", "200"},
      {"pct:60,45,25,25", "", "200"},
      {"pct:60,60,25,25", "", "200"}
    ]
  end

  defp cache_iiif_image(image) do
    # Generate iiif image server base url from hero image tuple
    {_, iiif_url} = image

    base_url =
      iiif_url
      |> String.split("/")
      |> Enum.drop(-4)
      |> Enum.join("/")

    hero_image_configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
  end

  defp cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "/#{region}/#{width},#{height}/0/default.jpg"

    options =
      [
        base_url: base_url,
        url: url
      ]
      |> Keyword.merge(Application.get_env(:dpul_collections, :hero_image_req_options, []))

    {:ok, %{status: 200}} = Req.request(options)
  end
end
