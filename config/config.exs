# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :dpul_collections, :scopes,
  user: [
    default: true,
    module: DpulCollections.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: DpulCollections.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

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

# Configures Oban job processing
config :dpul_collections, Oban,
  engine: Oban.Engines.Basic,
  queues: [cache: 20],
  repo: DpulCollections.Repo

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dpul_collections, DpulCollections.Mailer, adapter: Swoosh.Adapters.Local

config :phoenix_vite, PhoenixVite.Npm,
  assets: [args: [], cd: Path.expand("..", __DIR__)],
  vite: [
    args: ~w(exec -- vite),
    cd: Path.expand("../assets", __DIR__),
    env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}
  ]

config :live_svelte, ssr: true

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, JSON
config :ecto, :json_library, JSON
config :postgrex, :json_library, JSON

config :dpul_collections, :figgy_hydrator, poll_interval: 60000

config :dpul_collections, DpulCollectionsWeb.Gettext,
  default_locale: "en",
  locales: ~w(en es pt)

config :dpul_collections, :web_connections, figgy_url: "https://figgy.princeton.edu"

config :dpul_collections, DpulCollections.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# Turn on thumbnail caching
config :dpul_collections, :cache_thumbnails?, true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :ex_cldr,
  default_locale: "en",
  default_backend: DpulCollectionsWeb.Cldr

config :iconify_ex,
  env: config_env(),
  mode: :css,
  generated_icon_static_path: "./assets/css",
  default_class: nil

config :dpul_collections, environment_name: Mix.env() |> to_string()
