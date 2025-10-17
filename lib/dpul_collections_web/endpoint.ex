defmodule DpulCollectionsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dpul_collections

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_dpul_collections_key",
    signing_salt: "9HWrQEJB",
    same_site: "Lax"
  ]

  def session_options do
    @session_options
  end

  # Add the sandbox to the endpoint to support feature tests with database
  # operations.
  # See https://hexdocs.pm/phoenix_ecto/main.html#concurrent-browser-tests
  if Application.compile_env(:dpul_collections, :sql_sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox
  end

  socket "/live", Phoenix.LiveView.Socket,
    # user_agent is used by the SQL sandbox to support feature tests.
    # See https://hexdocs.pm/phoenix_test_playwright/PhoenixTest.Playwright.html#module-ecto-sql-sandbox
    websocket: [connect_info: [:user_agent, session: @session_options]],
    longpoll: [connect_info: [:user_agent, session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :dpul_collections,
    gzip: not code_reloading?,
    only: DpulCollectionsWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :dpul_collections
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug DpulCollectionsWeb.Router
end
