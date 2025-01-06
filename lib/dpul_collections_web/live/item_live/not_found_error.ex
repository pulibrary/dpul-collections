defmodule DpulCollectionsWeb.ItemLive.NotFoundError do
  defexception message: "Item not found", plug_status: 404
end
