defmodule DpulCollections.Georef.Manifest do
  @moduledoc """
  Pulls the parts of a IIIF Presentation 3 manifest needed for georeferencing:
  canvases (with their image service) and the coarse `navPlace` bounding box.
  """

  defmodule Canvas do
    @moduledoc false
    defstruct [:id, :label, :width, :height, :service_id, :service_type]
  end

  defstruct [:id, :label, :summary, :bbox, canvases: []]

  @doc "Fetch a manifest by URL, or resolve a maps.princeton.edu catalog URL to one."
  def fetch(url) do
    url = resolve_url(url)
    %{status: 200, body: body} = Req.get!(url, receive_timeout: 60_000)
    parse(body)
  end

  def resolve_url("https://maps.princeton.edu/catalog/" <> slug) do
    %{status: 200, body: raw} =
      Req.get!("https://maps.princeton.edu/catalog/#{slug}/raw", decode_body: false)

    refs = raw |> Jason.decode!() |> Map.fetch!("dct_references_s") |> Jason.decode!()
    Map.fetch!(refs, "http://iiif.io/api/presentation#manifest")
  end

  def resolve_url(url), do: url

  def parse(%{"id" => id} = m) do
    %__MODULE__{
      id: id,
      label: m |> Map.get("label", %{}) |> first_value(),
      summary: m |> Map.get("summary", %{}) |> Map.values() |> List.flatten(),
      bbox: nav_place_bbox(m["navPlace"]),
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
      service_id: service["@id"] || service["id"],
      service_type: service["type"] || service["@type"] || "ImageService2"
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

  defp first_value(map) when map == %{}, do: nil
  defp first_value(map), do: map |> Map.values() |> List.flatten() |> List.first()

  @doc "IIIF Image API URL for a region of a canvas, scaled to fit `max` px."
  def image_url(%Canvas{service_id: sid}, region \\ "full", max \\ 1536) do
    region =
      case region do
        "full" -> "full"
        {x, y, w, h} -> Enum.map_join([x, y, w, h], ",", &round/1)
      end

    "#{sid}/#{region}/!#{max},#{max}/0/default.jpg"
  end
end
