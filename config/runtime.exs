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

  solr_base_url =
    System.get_env("SOLR_BASE_URL") ||
      raise """
      environment variable SOLR_BASE_URL is missing.
      For example: http://localhost:8985
      """

  solr_read_collection =
    System.get_env("SOLR_READ_COLLECTION") ||
      raise """
      environment variable SOLR_READ_COLLECTION is missing.
      For example: dpul-collections-prod
      Note: This must be implemented as an alias
      """

  solr_config_set =
    System.get_env("SOLR_CONFIG_SET") ||
      raise """
      environment variable SOLR_CONFIG_SET is missing.
      For example: dpulc-staging
      Note: This must be deployed to the solr server via pul_solr
      """

  # Configure Solr connection
  config :dpul_collections, :solr, %{
    base_url: solr_base_url,
    read_collection: solr_read_collection,
    config_set: solr_config_set,
    username: System.get_env("SOLR_USERNAME") || "",
    password: System.get_env("SOLR_PASSWORD") || ""
  }

  {:ok, solr_config_json} = File.read(Path.join(System.get_env("NOMAD_TASK_DIR"), "solr.json"))
  config :dpul_collections, solr_config, Jason.decode(solr_config_json)

  index_cache_collections =
    System.get_env("INDEX_CACHE_COLLECTIONS")
    |> String.split(";")
    |> Enum.map(&String.split(&1, ","))
    |> Enum.map(fn list -> Enum.map(list, &String.split(&1, ":")) end)
    |> Enum.map(fn list -> Enum.map(list, &List.to_tuple/1) end)
    |> Enum.map(fn list ->
      Enum.map(list, fn tuple -> {String.to_atom(elem(tuple, 0)), elem(tuple, 1)} end)
    end) ||
      raise """
      environment variable INDEX_CACHE_COLLECTIONS is missing.
      This value must be passed as a json string
      For example: "cache_version:1,write_collection:dpulc-staging"
      For example: "cache_version:1,write_collection:dpulc-staging1;cache_version:2,write_collection:dpulc-staging2"
      Note: up to 2 collections can be specified. Code is untested beyond 2.
      Note: never add a cache version that's lower in value than the current active cache version
      """

  # Configure indexing pipeline writes
  config :dpul_collections, DpulCollections.IndexingPipeline, index_cache_collections

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

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :dpul_collections, DpulCollectionsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :dpul_collections, DpulCollectionsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :dpul_collections, DpulCollections.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
