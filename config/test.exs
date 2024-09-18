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
  pool_size: System.schedulers_online() * 2

# Configure your other database
config :dpul_collections, DpulCollections.FiggyRepo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("TEST_POSTGRES_FIGGY_HOST") || "localhost",
  port: System.get_env("TEST_POSTGRES_PORT") || 5435,
  database: "postgres",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "fS76i6oeLWDlMP7AEe+nExNz3J4tHyaIZrELNhSmY3LUocagaphwGc8Ff7rAh6qS",
  server: false

# In test we don't send emails.
config :dpul_collections, DpulCollections.Mailer, adapter: Swoosh.Adapters.Test

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
config :dpul_collections, :solr, url: System.get_env("SOLR_URL") || "http://localhost:8984/solr/dpulc-test"
