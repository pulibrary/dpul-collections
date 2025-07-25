import Config

# Configure your database
config :dpul_collections, DpulCollections.Repo,
  username: "postgres",
  password: "",
  hostname: "localhost",
  port: "5434",
  database: "dpul_collections_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure your other database
config :dpul_collections, DpulCollections.FiggyRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: "5435",
  database: "postgres",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "0SRtMTVbFVxGojwWaaVDQUu8diAcl+d6I+DUQeSsSZSG+7ESn2ac9Wnzl/gVYyUT",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:dpul_collections, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:dpul_collections, ~w(--watch)]}
  ]

# ## SSL Support
#
# In order to use HTTPS in development, a self-signed
# certificate can be generated by running the following
# Mix task:
#
#     mix phx.gen.cert
#
# Run `mix help phx.gen.cert` for more information.
#
# The `http:` config above can be replaced with:
#
#     https: [
#       port: 4001,
#       cipher_suite: :strong,
#       keyfile: "priv/cert/selfsigned_key.pem",
#       certfile: "priv/cert/selfsigned.pem"
#     ],
#
# If desired, both `http:` and `https:` keys can be
# configured to run both http and https servers on
# different ports.

# Watch static and templates for browser reloading.
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/dpul_collections_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :dpul_collections, :basic_auth_username, "admin"
config :dpul_collections, :basic_auth_password, "admin"

# Enable dev routes for dashboard and mailbox
config :dpul_collections, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
config :logger, level: :info

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Configure Solr connection
config :dpul_collections, :solr, %{
  base_url: System.get_env("SOLR_BASE_URL") || "http://localhost:8985",
  read_collection: "dpulc",
  config_set: "dpul-collections",
  username: System.get_env("SOLR_USERNAME") || "user",
  password: System.get_env("SOLR_PASSWORD") || "pass"
}

# only run indexing children if the webserver is running
# wrap this in a function b/c Phoenix.Endpoint.server? is not defined at config time
config :dpul_collections, :start_indexing_pipeline?, fn ->
  Phoenix.Endpoint.server?(:dpul_collections, DpulCollectionsWeb.Endpoint)
end

# Configure indexing pipeline writes
config :dpul_collections, DpulCollections.IndexingPipeline, [
  [
    cache_version: 1,
    write_collection: "dpulc1"
  ]
]

# Turn off thumbnail caching during local development
config :dpul_collections, :cache_thumbnails?, false

config :honeybadger, api_key: ""
