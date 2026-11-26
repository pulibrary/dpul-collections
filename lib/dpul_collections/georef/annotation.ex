defmodule DpulCollections.Georef.Annotation do
  @moduledoc """
  Builds IIIF Georeference Annotations (https://iiif.io/api/extension/georef/).

  Each georeferenced canvas becomes one Annotation whose target is a
  SpecificResource: the canvas plus an SvgSelector polygon masking the map
  area. All annotations for a manifest are collected in one AnnotationPage,
  which Allmaps Viewer can open directly.
  """

  @context [
    "http://iiif.io/api/extension/georef/1/context.json",
    "http://iiif.io/api/presentation/3/context.json"
  ]

  @doc """
  `results` is a list of maps with :canvas, :mask ([{x, y}, ...] in canvas
  pixels) and :gcps ([%{px: {x, y}, lonlat: [lon, lat], label: str}]).
  """
  def page(manifest, results, opts \\ []) do
    base = Keyword.get(opts, :base_id, manifest.id <> "/georef")

    %{
      "@context" => @context,
      "id" => base,
      "type" => "AnnotationPage",
      "items" =>
        results
        |> Enum.with_index(1)
        |> Enum.map(fn {r, i} -> annotation(manifest, r, "#{base}/#{i}") end)
    }
  end

  def annotation(manifest, %{canvas: canvas, mask: mask, gcps: gcps} = r, id) do
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
          "type" => canvas.service_type || "ImageService2",
          "width" => round(canvas.width * canvas.px_scale),
          "height" => round(canvas.height * canvas.px_scale),
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
        "transformation" =>
          Map.get(r, :transformation, %{"type" => "polynomial", "options" => %{"order" => 1}}),
        "features" => Enum.map(gcps, &feature(&1, canvas.px_scale))
      }
    }
  end

  defp feature(%{px: {x, y}, lonlat: [lon, lat]} = g, k) do
    props = %{"resourceCoords" => [round(x * k), round(y * k)]}
    props = if g[:label], do: Map.put(props, "label", g.label), else: props

    %{
      "type" => "Feature",
      "properties" => props,
      "geometry" => %{
        "type" => "Point",
        "coordinates" => [Float.round(lon, 7), Float.round(lat, 7)]
      }
    }
  end

  def svg(mask, canvas) do
    k = canvas.px_scale
    {w, h} = {round(canvas.width * k), round(canvas.height * k)}

    points =
      Enum.map_join(mask, " ", fn {x, y} -> "#{clamp(x * k, w)},#{clamp(y * k, h)}" end)

    ~s(<svg width="#{w}" height="#{h}"><polygon points="#{points}" /></svg>)
  end

  defp clamp(v, limit), do: v |> round() |> max(0) |> min(limit)
end
