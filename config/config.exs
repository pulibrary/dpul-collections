# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dpul_collections,
  ecto_repos: [DpulCollections.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :dpul_collections, DpulCollectionsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DpulCollectionsWeb.ErrorHTML, json: DpulCollectionsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DpulCollections.PubSub,
  live_view: [signing_salt: "Z37237LW"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dpul_collections, DpulCollections.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  dpul_collections: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  dpul_collections: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :dpul_collections, :figgy_hydrator, poll_interval: 60000

config :dpul_collections, DpulCollectionsWeb.Gettext,
  default_locale: "en",
  locales: ~w(en es)

config :dpul_collections, :web_connections, figgy_url: "https://figgy.princeton.edu"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
