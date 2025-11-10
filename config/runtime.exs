import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/dpul_collections start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :dpul_collections, DpulCollectionsWeb.Endpoint, server: true
end

if config_env() == :prod do
  config :dpul_collections, environment_name: System.get_env("APP_ENV")

  # Feature flips
  config :dpul_collections, :feature_account_toolbar, false

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :dpul_collections, DpulCollections.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "30"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  figgy_database_url =
    System.get_env("FIGGY_DATABASE_URL") ||
      raise """
      environment variable FIGGY_DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  # Configure your other database
  config :dpul_collections, DpulCollections.FiggyRepo,
    url: figgy_database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "30"),
    socket_options: maybe_ipv6

  # Solr configuration
  {:ok, solr_config_json} = File.read(Path.join(System.get_env("NOMAD_TASK_DIR"), "solr.json"))
  {:ok, solr_config} = Jason.decode(solr_config_json, keys: :atoms)
  config :dpul_collections, :solr_config, solr_config

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")
  check_origin = true

  config :dpul_collections, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # only run indexing children if the webserver is running
  # wrap this in a function b/c the dev implementation requires it
  config :dpul_collections, :start_indexing_pipeline?, fn ->
    if System.get_env("INDEXER") do
      true
    else
      false
    end
  end

  # Configure basic auth
  config :dpul_collections, :basic_auth_username, System.get_env("BASIC_AUTH_USERNAME")
  config :dpul_collections, :basic_auth_password, System.get_env("BASIC_AUTH_PASSWORD")

  config :dpul_collections, DpulCollectionsWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    check_origin: check_origin,
    secret_key_base: secret_key_base

  config :dpul_collections, DpulCollections.PromEx,
    disabled: false,
    manual_metrics_start_delay: :no_delay,
    drop_metrics_groups: [],
    # Upload pre-built dashboards to Grafana.
    grafana: [
      host: "https://grafana-nomad.lib.princeton.edu",
      auth_token: System.get_env("GRAFANA_SERVICE_TOKEN")
    ],
    # Run a standalone metrics server with a bearer token auth. Prometheus will
    # harvest metrics from this server.
    metrics_server: [
      port: 4021,
      auth_strategy: :bearer,
      auth_token: System.get_env("METRICS_AUTH_TOKEN"),
      cowboy_opts: [
        ip: {0, 0, 0, 0}
      ]
    ]

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # Here is an example configuration for Mailgun:
  #
  #     config :dpul_collections, DpulCollections.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  if System.get_env("APP_ENV") == "staging" do
    config :dpul_collections, :feature_account_toolbar, true

    config :dpul_collections, DpulCollections.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: System.get_env("SMTP_HOST"),
      auth: :never,
      ssl: false,
      tls: :never,
      retries: 2,
      no_mx_lookups: true
  end
end
