defmodule DpulCollections.Workers.CacheHeroImages do
  use Oban.Worker, queue: :cache

  @impl Oban.Worker
  def perform(%Oban.Job{args: _}) do
    # Cache hero thumbnails
    DpulCollectionsWeb.HomeLive.hero_images()
    |> Enum.each(&cache_iiif_image(&1))
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
    {_, base_url} = image
    hero_image_configurations() |> Enum.each(&cache_iiif_image(base_url, &1))
  end

  defp cache_iiif_image(base_url, configuration) do
    {region, width, height} = configuration
    url = "#{base_url}/#{region}/#{width},#{height}/0/default.jpg"
  end
end
