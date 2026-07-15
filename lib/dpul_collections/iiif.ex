defmodule DpulCollections.IIIF do
  @moduledoc """
  Centralized IIIF Image API request parameters.
  Returns service path using this template:
    `{region}/{size}/{rotation}/{quality}.{format}`
  """

  # Small browse thumbnails
  def small_browse_thumbnail_parameters, do: image_parameters("square", "!100,100")

  # Browse and search results thumbnails
  def result_thumbnail_parameters, do: image_parameters("square", "!350,350")

  # Search results primary thumbnails
  def primary_search_thumbnail_parameters, do: image_parameters("full", "!350,350")

  # Item page thumbnails
  def item_thumbnail_parameters, do: image_parameters("square", "!350,465")

  # Clover thumbnails
  def clover_thumbnail_parameters, do: image_parameters("full", "!200,150")

  # Thumbnails based on specific width and height
  def primary_thumbnail_parameters(width, height) do
    image_parameters("full", "!#{width},#{height}")
  end

  defp image_parameters(region, size) do
    "#{region}/#{size}/0/default.jpg"
  end
end
