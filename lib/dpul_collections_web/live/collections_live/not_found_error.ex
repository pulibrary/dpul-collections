defmodule DpulCollectionsWeb.CollectionsLive.NotFoundError do
  defexception message: "Collection not found", plug_status: 404
end
