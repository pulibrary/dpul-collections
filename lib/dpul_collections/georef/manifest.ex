defmodule DpulCollections.Georef.Manifest do
  @moduledoc """
  Pulls the parts of a IIIF Presentation 3 manifest needed for georeferencing:
  canvases (with their image service) and the coarse `navPlace` bounding box.
  """

  defmodule Canvas do
    @moduledoc false
    # width/height are in pipeline pixels: a Sanborn sheet (~25.5 in tall)
    # scanned far from Princeton's ~395 dpi (LoC: 300 dpi) is given a virtual
    # 395 dpi pixel grid, so every scale and pixel-size constant holds;
    # px_scale (image px per pipeline px) converts at the image service and
    # in the output annotation.
    defstruct [:id, :label, :width, :height, :service_id, :service_type, px_scale: 1.0]
  end

  defstruct [:id, :label, :summary, :bbox, subject_places: [], canvases: []]

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
      subject_places: subject_places(m["metadata"] || []),
      canvases: Enum.map(m["items"] || [], &parse_canvas/1)
    }
  end

  @nominal_dpi 395
  @sheet_in 25.5

  defp parse_canvas(c) do
    body = get_in(c, ["items", Access.at(0), "items", Access.at(0), "body"])
    service = body |> Map.get("service", []) |> List.first(%{})
    {w, h} = {c["width"], c["height"]}
    k = px_scale(w, h)

    %Canvas{
      id: c["id"],
      label: c |> Map.get("label", %{}) |> first_value(),
      width: if(k == 1.0, do: w, else: round(w / k)),
      height: if(k == 1.0, do: h, else: round(h / k)),
      px_scale: k,
      service_id: service["@id"] || service["id"],
      service_type: service["type"] || service["@type"] || "ImageService2"
    }
  end

  @doc """
  Image px per pipeline px. Scan resolution is estimated from the long side
  (Sanborn sheets are ~#{@sheet_in} in): Princeton's scans come out at
  390-408 dpi and are left alone (1.0); LoC's 6450 x 7650 px (300 dpi) get 0.76.
  """
  def px_scale(w, h) when is_number(w) and is_number(h) do
    dpi = max(w, h) / @sheet_in
    if dpi > 360 and dpi < 430, do: 1.0, else: dpi / @nominal_dpi
  end

  def px_scale(_, _), do: 1.0

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

  @doc "IIIF Image API URL for a region of a canvas, scaled to fit `max` px."
  def image_url(%Canvas{service_id: sid, px_scale: k}, region \\ "full", max \\ 1536) do
    region =
      case region do
        "full" -> "full"
        {x, y, w, h} -> Enum.map_join([x, y, w, h], ",", &round(&1 * k))
      end

    "#{sid}/#{region}/!#{max},#{max}/0/default.jpg"
  end
end
