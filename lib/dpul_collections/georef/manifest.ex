defmodule DpulCollections.Georef.Manifest do
  @moduledoc """
  Pulls the parts of a IIIF Presentation 3 manifest needed for georeferencing:
  canvases (with their image service) and the coarse `navPlace` bounding box.
  """

  defmodule Canvas do
    @moduledoc false
    defstruct [:id, :label, :width, :height, :service_id]
  end

  # version: the IIIF Presentation API version (2's canvas sizes can be a reduced copy's)
  defstruct [:id, :label, :bbox, version: 3, subject_places: [], canvases: []]

  @doc "Fetch and parse a manifest."
  def fetch(url) do
    opts = Keyword.merge([receive_timeout: 60_000], DpulCollections.Georef.req_options())

    case Req.get!(url, opts) do
      %{status: 200, body: body} -> parse(body)
      %{status: status} -> raise "manifest fetch failed for #{url}: HTTP #{status}"
    end
  end

  @doc """
  Each canvas's size from its image service's info.json. A Presentation 2
  canvas can be sized to a reduced copy (the Library of Congress's are a
  quarter of the image), but every pixel coordinate here is the full image's.
  """
  def with_image_sizes(%__MODULE__{} = m) do
    opts = Keyword.merge([receive_timeout: 60_000], DpulCollections.Georef.req_options())

    canvases =
      m.canvases
      |> Task.async_stream(
        fn
          %Canvas{service_id: nil} = c ->
            c

          c ->
            case Req.get!(c.service_id <> "/info.json", opts) do
              %{status: 200, body: body} ->
                info = if is_binary(body), do: Jason.decode!(body), else: body
                %{c | width: info["width"], height: info["height"]}

              %{status: status} ->
                raise "image info failed for #{c.service_id}: HTTP #{status}"
            end
        end,
        max_concurrency: 4,
        timeout: 120_000
      )
      |> Enum.map(fn {:ok, c} -> c end)

    %{m | canvases: canvases}
  end

  # IIIF Presentation 2 (the Library of Congress's manifests): canvases under sequences,
  # labels as plain strings, no navPlace
  def parse(%{"@id" => id, "sequences" => [seq | _]} = m) do
    %__MODULE__{
      id: id,
      version: 2,
      label: v2_string(m["label"]),
      bbox: nil,
      subject_places: [],
      canvases:
        for c <- seq["canvases"] || [] do
          service = get_in(c, ["images", Access.at(0), "resource", "service"]) || %{}
          service = if is_list(service), do: List.first(service, %{}), else: service

          %Canvas{
            id: c["@id"],
            label: v2_string(c["label"]),
            width: c["width"],
            height: c["height"],
            service_id: service["@id"] || service["id"]
          }
        end
    }
  end

  def parse(%{"id" => id} = m) do
    %__MODULE__{
      id: id,
      label: m |> Map.get("label", %{}) |> first_value(),
      bbox: nav_place_bbox(m["navPlace"]),
      subject_places: subject_places(m["metadata"] || []),
      canvases: Enum.map(m["items"] || [], &parse_canvas/1)
    }
  end

  defp parse_canvas(c) do
    body = get_in(c, ["items", Access.at(0), "items", Access.at(0), "body"])
    service = body |> Map.get("service", []) |> List.first(%{})

    %Canvas{
      id: c["id"],
      label: c |> Map.get("label", %{}) |> first_value(),
      width: c["width"],
      height: c["height"],
      service_id: service["@id"] || service["id"]
    }
  end

  # {min_lon, min_lat, max_lon, max_lat}
  defp nav_place_bbox(nil), do: nil

  defp nav_place_bbox(%{"features" => features}) do
    coords =
      features
      |> Enum.flat_map(fn f -> f |> get_in(["geometry", "coordinates"]) |> List.flatten() end)
      |> Enum.chunk_every(2)

    {lons, lats} = coords |> Enum.map(fn [x, y] -> {x, y} end) |> Enum.unzip()
    {Enum.min(lons), Enum.min(lats), Enum.max(lons), Enum.max(lats)}
  end

  # "Real property—New Jersey—Carteret—Maps" -> "Carteret": the catalog's
  # present-day place, which a title can predate (Roosevelt, 1912 = Carteret).
  defp subject_places(metadata) do
    metadata
    |> Enum.filter(fn x -> x |> Map.get("label", %{}) |> first_value() == "Subject" end)
    |> Enum.flat_map(fn x -> x |> Map.get("value", %{}) |> Map.values() |> List.flatten() end)
    |> Enum.flat_map(fn v ->
      case String.split(v, "—") do
        [_, _state, place | _] -> if place =~ ~r/county$/i, do: [], else: [String.trim(place)]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp first_value(map) when map == %{}, do: nil
  defp first_value(map), do: map |> Map.values() |> List.flatten() |> List.first()

  defp v2_string(s) when is_binary(s), do: s
  defp v2_string([s | _]), do: v2_string(s)
  defp v2_string(%{"@value" => s}), do: s
  defp v2_string(_), do: nil
end
