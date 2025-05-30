import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Enable dev routes - including mailbox preview and the dashboard.
config :dpul_collections, dev_routes: true

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Finch, finch_name: DpulCollections.Finch

# Disable Swoosh Local Memory Storage
config :swoosh, local: false

# Do not print debug messages in production
config :logger, level: :info

config :honeybadger, environment_name: :staging

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
