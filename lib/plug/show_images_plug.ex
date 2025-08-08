defmodule DpulCollectionsWeb.ShowImagesPlug do
  @moduledoc """
  Pull from the show images cookie into session so liveviews can render
  desired images
  """

  import Plug.Conn

  def init(_opts) do
    []
  end

  def call(conn, _) do
    case fetch_cookie(conn) do
      nil ->
        conn

      image_ids ->
        conn
        |> put_session(:show_images, image_ids)
    end
  end

  defp fetch_cookie(conn) do
    conn.cookies["showImages1"] |> validate_ids()
  end

  defp validate_ids(nil), do: nil

  defp validate_ids(ids) do
    # TODO: ensure they're all UUIDs
    String.split(ids, ",")
  end
end
