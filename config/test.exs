import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

config :dpul_collections, DpulCollections.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: System.get_env("TEST_POSTGRES_PORT") || 5434,
  database: "dpul_collections_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # in ms, 30 min, allows dbg in tests
  ownership_timeout: 1_800_000

# Configure your other database
config :dpul_collections, DpulCollections.FiggyRepo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("TEST_POSTGRES_FIGGY_HOST") || "localhost",
  port: System.get_env("TEST_POSTGRES_FIGGY_PORT") || 5435,
  database: "postgres",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  # in ms, 30 min, allows dbg in tests
  ownership_timeout: 1_800_000

# Playwright feature tests require the server to be running
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fS76i6oeLWDlMP7AEe+nExNz3J4tHyaIZrELNhSmY3LUocagaphwGc8Ff7rAh6qS",
  server: true

# In test, don't run jobs
config :dpul_collections, Oban, testing: :manual

# In test we don't send emails.
config :dpul_collections, DpulCollections.Mailer, adapter: Swoosh.Adapters.Test

# Set basic auth
config :dpul_collections, :basic_auth_username, "admin"
config :dpul_collections, :basic_auth_password, "test"
# Enable dev routes for dashboard and mailbox
config :dpul_collections, dev_routes: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Configure Solr connection
config :dpul_collections, :solr, %{
  base_url: System.get_env("SOLR_BASE_URL") || "http://localhost:8984",
  read_collection: "dpulc",
  config_set: "dpul-collections",
  username: "solr",
  password: "SolrRocks"
}

# don't run indexing children
# wrap this in a function b/c the dev implementation requires it
config :dpul_collections, :start_indexing_pipeline?, fn -> false end

# Set this poll interval really small so it triggers in test.
config :dpul_collections, :figgy_hydrator, poll_interval: 50

config :dpul_collections, :web_connections, figgy_url: "https://figgy.example.com"

# Stub http requests in CacheThumbnails Oban worker
config :dpul_collections,
  thumbnail_req_options: [
    plug: {Req.Test, DpulCollections.Workers.CacheThumbnails}
  ]

# Stub http requests in CacheHeroImages Oban worker
config :dpul_collections,
  hero_image_req_options: [
    plug: {Req.Test, DpulCollections.Workers.CacheHeroImages}
  ]

config :phoenix_test,
  otp_app: :dpul_collections,
  endpoint: DpulCollectionsWeb.Endpoint,
  playwright: [
    browser: :chromium,
    headless: System.get_env("PW_HEADLESS", "true") in ~w(t true),
    js_logger: false,
    screenshot: System.get_env("PW_SCREENSHOT", "false") in ~w(t true),
    trace: System.get_env("PW_TRACE", "false") in ~w(t true),
    browser_launch_timeout: 10_000
  ]

config :honeybadger, api_key: ""
