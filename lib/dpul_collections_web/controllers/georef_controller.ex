defmodule DpulCollectionsWeb.GeorefController do
  @moduledoc """
  Dev-only: serves Georeference AnnotationPages written by `mix georef` to
  tmp/georef, with CORS so viewer.allmaps.org can load them via `?url=`.
  """
  use DpulCollectionsWeb, :controller

  def show(conn, %{"file" => file}) do
    path = Path.join("tmp/georef", Path.basename(file))

    if String.ends_with?(path, ".json") and File.regular?(path) do
      conn
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_content_type("application/json")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "not found")
    end
  end
end
