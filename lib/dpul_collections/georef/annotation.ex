defmodule DpulCollections.Georef.Annotation do
  @moduledoc """
  Builds IIIF Georeference Annotations (https://iiif.io/api/extension/georef/):
  one per map part, whose target is the sheet's image service with an
  SvgSelector polygon masking the part. Allmaps Viewer opens them directly.
  """

  @doc """
  `canvas`: %{id, service_id, width, height}; `manifest`: %{id, label};
  `mask`: [{x, y}] in canvas pixels; `gcps`: [%{px: {x, y}, lonlat: [lon, lat], label: str}].
  """
  def annotation(manifest, canvas, mask, gcps, id) do
    %{
      "id" => id,
      "type" => "Annotation",
      "motivation" => "georeferencing",
      "target" => %{
        "type" => "SpecificResource",
        # Allmaps fetches pixels through the image service, so target it
        # directly and keep the canvas/manifest link in partOf.
        "source" => %{
          "id" => canvas.service_id,
          "type" => "ImageService2",
          "width" => canvas.width,
          "height" => canvas.height,
          "partOf" => [
            %{
              "id" => canvas.id,
              "type" => "Canvas",
              "partOf" => [
                %{
                  "id" => manifest.id,
                  "type" => "Manifest",
                  "label" => %{"none" => [manifest.label]}
                }
              ]
            }
          ]
        },
        "selector" => %{"type" => "SvgSelector", "value" => svg(mask, canvas)}
      },
      "body" => %{
        "type" => "FeatureCollection",
        "transformation" => %{"type" => "polynomial", "options" => %{"order" => 1}},
        "features" => Enum.map(gcps, &feature/1)
      }
    }
  end

  defp feature(%{px: {x, y}, lonlat: [lon, lat], label: label}) do
    %{
      "type" => "Feature",
      "properties" => %{"resourceCoords" => [round(x), round(y)], "label" => label},
      "geometry" => %{
        "type" => "Point",
        "coordinates" => [Float.round(lon, 7), Float.round(lat, 7)]
      }
    }
  end

  defp svg(mask, %{width: w, height: h}) do
    points = Enum.map_join(mask, " ", fn {x, y} -> "#{clamp(x, w)},#{clamp(y, h)}" end)
    ~s(<svg width="#{w}" height="#{h}"><polygon points="#{points}" /></svg>)
  end

  defp clamp(v, limit), do: v |> round() |> max(0) |> min(limit)
end
