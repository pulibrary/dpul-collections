defmodule DpulCollectionsWeb.Georeferencer.Routes do
  @moduledoc """
  The collaborative georeferencer's routes (`use`d by the router) and its
  switch: `config :dpul_collections, :georeferencer, enabled: true`. Switched
  off (the default), every georeferencer request is a 404. See
  docs/tech/georeferencing.md for what to delete to remove it.
  """
  import Plug.Conn

  def enabled?,
    do: Application.get_env(:dpul_collections, :georeferencer, []) |> Keyword.get(:enabled, false)

  # as a plug: 404 while switched off
  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?(), do: conn, else: conn |> send_resp(404, "Not Found") |> halt()
  end

  # LiveView websocket mounts don't pass through plugs
  def on_mount(:enabled, _params, _session, socket) do
    if enabled?(), do: {:cont, socket}, else: raise(DpulCollectionsWeb.ItemLive.NotFoundError)
  end

  # A macro runs when the router compiles, before coverage is measured.
  # coveralls-ignore-start
  defmacro __using__(_opts) do
    quote do
      # Data, images, models and downloads need no session (and the CSRF plug
      # would refuse to serve the OCR runtime's JavaScript module).
      scope "/georeferencer", DpulCollectionsWeb.Georeferencer do
        pipe_through [DpulCollectionsWeb.Georeferencer.Routes]

        get "/input/:atlas/:index", Controller, :input
        get "/image", Controller, :image
        get "/ocr/:file", Controller, :ocr_file
        get "/atlas/:atlas/osm.json", Controller, :osm
        get "/contributions/:id", Controller, :contribution
        get "/atlas/:atlas/georef.json", Controller, :atlas_page
      end

      scope "/georeferencer", DpulCollectionsWeb.Georeferencer do
        pipe_through [:browser, DpulCollectionsWeb.Georeferencer.Routes]

        live_session :georeferencer,
          on_mount:
            with_sandbox_support([
              {DpulCollectionsWeb.Georeferencer.Routes, :enabled},
              {DpulCollectionsWeb.CurrentPathHook, :global},
              {DpulCollectionsWeb.UserAuth, :mount_current_scope}
            ]) do
          live "/", QueueLive, :show
          live "/results", ResultsLive, :index
          live "/review", ReviewLive, :index
          live "/review/:atlas/:index", ReviewLive, :show
          live "/:atlas/:index", SheetLive, :show
        end
      end
    end
  end

  # coveralls-ignore-stop
end
