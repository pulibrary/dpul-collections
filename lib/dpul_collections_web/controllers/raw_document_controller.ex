defmodule DpulCollectionsWeb.RawDocumentController do
  use DpulCollectionsWeb, :controller
  alias DpulCollections.Solr

  def item(conn, %{"id" => id}) do
    case Solr.find_by_id(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Item not found"})

      doc ->
        json(conn, doc)
    end
  end

  def collection(conn, %{"slug" => slug}) do
    case Solr.find_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Collection not found"})

      doc ->
        json(conn, doc)
    end
  end
end
