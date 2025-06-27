defmodule DpulCollectionsWeb.IiifContentStateController do
  use DpulCollectionsWeb, :controller
  alias DpulCollections.Item
  alias DpulCollections.Solr

  @doc """
  Generates a IIIF Content State JSON for a canvas in the manifest.
  This endpoint is used to support jumping to a specific page in the Clover viewer.
  """
  def show(conn, %{"id" => id, "canvas_index" => canvas_index}) when is_bitstring(canvas_index) do
    case Integer.parse(canvas_index) do
      {index, ""} when index >= 0 ->
        show(conn, %{"id" => id, "canvas_index" => index})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid canvas index"})
    end
  end

  def show(conn, %{"id" => id, "canvas_index" => canvas_index}) do
    item = Solr.find_by_id(id) |> Item.from_solr()

    case item do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Item not found"})

      item ->
        canvas_id = item.image_canvas_ids |> Enum.at(canvas_index)

        case canvas_id do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Canvas not found"})

          _ ->
            content_state = generate_content_state(conn, item, canvas_id)

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(content_state))
        end
    end
  end

  defp generate_content_state(conn, item, canvas_id) do
    %{
      "@context" => "http://iiif.io/api/presentation/3/context.json",
      "id" => current_url(conn),
      "type" => "Annotation",
      "motivation" => ["contentState"],
      "target" => %{
        "id" => canvas_id,
        "type" => "Canvas",
        "partOf" => [
          %{
            "id" => item.iiif_manifest_url,
            "type" => "Manifest"
          }
        ]
      }
    }
  end
end
