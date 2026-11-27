defmodule DpulCollectionsWeb.Georeferencer.Controller do
  @moduledoc """
  Inputs for the in-browser georeferencer and downloads of its results.
  The fitting itself runs in the contributor's browser (assets/js/georeferencer/).
  """
  use DpulCollectionsWeb, :controller
  alias DpulCollections.Georef
  alias DpulCollections.Georef.Collab

  def input(conn, %{"atlas" => id, "index" => i}) do
    with atlas when atlas != nil <- Collab.atlas(id),
         {i, ""} <- Integer.parse(i),
         true <- i >= 0 and i < length(atlas["canvases"]) do
      json(conn, Collab.sheet_input(atlas, i))
    else
      _ -> send_resp(conn, 404, "not found")
    end
  end

  def osm(conn, %{"atlas" => id}) do
    case Collab.atlas(id) do
      nil ->
        send_resp(conn, 404, "not found")

      atlas ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("cache-control", "private, max-age=3600")
        |> send_resp(200, Collab.osm_payload(atlas))
    end
  end

  # Same-origin copy of a sheet image (or a region of it) so the browser may
  # read its pixels. Sizes are the ones the server pipeline uses, so its image
  # cache is shared: "3000," for the corridor maps, "!3000,3000" for the whole-
  # sheet OCR, "!1536,1536" for OCR tiles.
  @sizes ["3000,", "!3000,3000", "!2000,2000", "!1536,1536"]
  def image(conn, %{"service" => service} = params) do
    region = Map.get(params, "region", "full")
    size = Map.get(params, "size", "3000,")

    if Collab.allowed_service?(service) and size in @sizes and
         (region == "full" or region =~ ~r/\A\d{1,6},\d{1,6},\d{1,6},\d{1,6}\z/) do
      conn
      |> put_resp_content_type("image/jpeg")
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> send_resp(200, Georef.fetch_image("#{service}/#{region}/#{size}/0/default.jpg"))
    else
      send_resp(conn, 400, "unsupported image request")
    end
  end

  # The OCR models (PP-OCRv6 det/rec small, v2 angle classifier, the
  # recogniser's character list) and onnxruntime-web's WebGPU runtime.
  @models ~w(det.onnx cls.onnx rec.onnx keys.json)
  @runtime ~w(ort-wasm-simd-threaded.jsep.mjs ort-wasm-simd-threaded.jsep.wasm)
  def ocr_file(conn, %{"file" => file}) do
    path =
      cond do
        file in @models -> Path.join(Collab.ocr_model_dir(), file)
        file in @runtime -> Path.join("assets/node_modules/onnxruntime-web/dist", file)
        file == "leaflet.css" -> "assets/node_modules/leaflet/dist/leaflet.css"
        true -> nil
      end

    type =
      case Path.extname(file) do
        ".wasm" -> "application/wasm"
        ".mjs" -> "text/javascript"
        ".json" -> "application/json"
        ".css" -> "text/css"
        _ -> "application/octet-stream"
      end

    if path && File.regular?(path) do
      conn
      |> put_resp_content_type(type, nil)
      |> put_resp_header("cache-control", "public, max-age=604800")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "not found")
    end
  end

  def contribution(conn, %{"id" => id}) do
    c = Collab.get!(id)

    body =
      c.annotation ||
        %{"verdict" => c.verdict, "canvas" => c.canvas_id, "part" => c.part}

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("content-disposition", ~s(inline; filename="georef-#{id}.json"))
    |> json(body)
  end

  def atlas_page(conn, %{"atlas" => id}) do
    case Collab.atlas(id) do
      nil ->
        send_resp(conn, 404, "not found")

      atlas ->
        conn
        |> put_resp_header("access-control-allow-origin", "*")
        |> json(Collab.atlas_page(atlas))
    end
  end
end
