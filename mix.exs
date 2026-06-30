defmodule DpulCollections.MixProject do
  use Mix.Project

  def project do
    [
      app: :dpul_collections,
      version: "0.1.0",
      elixir: "~> 1.19.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test,
        spec: :test
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {DpulCollections.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "== 1.8.7"},
      {:phoenix_ecto, "== 4.7.0"},
      {:ecto_sql, "== 3.14.0"},
      {:postgrex, "== 0.22.2"},
      {:phoenix_html, "== 4.3.0"},
      {:phoenix_live_reload, "== 1.6.2", only: :dev},
      {:phoenix_live_view, "== 1.1.30"},
      {:floki, "== 0.38.2", only: :test},
      {:phoenix_live_dashboard, "== 0.8.7"},
      {:esbuild, "== 0.10.0", runtime: Mix.env() == :dev},
      {:tailwind, "== 0.4.1", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "== 1.25.2"},
      {:gen_smtp, "== 1.3.0"},
      {:telemetry_metrics, "== 1.1.0"},
      {:telemetry_poller, "== 1.3.0"},
      {:gettext, "== 1.0.2"},
      {:jason, "== 1.4.5"},
      {:dns_cluster, "== 0.2.0"},
      {:bandit, "== 1.11.1"},
      {:excoveralls, "== 0.18.5", only: :test},
      {:broadway, "== 1.3.0"},
      {:ex_doc, "== 0.40.2", only: :dev, runtime: false},
      {:req, "== 0.5.18"},
      {:broadway_dashboard, "== 0.4.1"},
      {:honeybadger, "== 0.27.0"},
      {:phoenix_test_playwright, "== 0.14.0", only: :test, runtime: false},
      {:live_debugger, "== 0.8.0", only: :dev},
      {:prom_ex, "== 1.11.0"},
      {:ecto_psql_extras, "== 0.8.8"},
      # Sibyl adds a decorator that automatically wraps a method and makes it
      # send telemetry events.
      {:sibyl, "== 0.1.11"},
      # Required to run metrics server
      {:plug_cowboy, "== 2.8.1"},
      {:ex_cldr_dates_times, "== 2.25.6"},
      # Icons
      {:iconify_ex, "== 0.7.2"},
      # React for Clover Viewer
      {:phoenix_live_react, "== 0.6.0"},
      {:sham, "== 1.2.5", only: :test},
      {:oban, "== 2.22.1"},
      {:oban_web, "== 2.12.4"},
      {:a11y_audit, "== 0.3.4", only: :test},
      {:mock, "== 0.3.9", only: :test},
      {:lazy_html, "== 0.1.11", only: :test},
      {:ex_cldr_locale_display, "== 1.7.3"},
      {:junit_formatter, "== 3.4.0", only: [:test]},
      {:flow, "== 1.2.4"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: [
        "deps.get",
        "ecto.setup",
        "assets.setup",
        "assets.build",
        "fixtures.setup",
        "reindex_dev"
      ],
      "setup.ci": [
        "deps.get",
        "ecto.setup",
        "assets.setup.ci",
        "assets.build",
        "fixtures.setup",
        "reindex_dev"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "assets.build",
        "coveralls.html"
      ],
      "fixtures.setup": [
        "cmd --cd ./figgy-fixture-container ./import-container-fixtures.sh 2> /dev/null || true"
      ],
      "assets.setup": [
        "cmd npm --prefix deps/iconify_ex/assets install",
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm --prefix assets install",
        "cmd npm --prefix assets exec playwright install chromium --with-deps"
      ],
      "assets.setup.ci": [
        "cmd npm --prefix deps/iconify_ex/assets ci --ignore-scripts",
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm --prefix assets ci --ignore-scripts",
        "cmd npm --prefix assets exec playwright install chromium --with-deps"
      ],
      "assets.build": ["tailwind dpul_collections", "esbuild dpul_collections"],
      "assets.deploy": [
        "tailwind dpul_collections --minify",
        "cmd --cd assets npm ci",
        "esbuild dpul_collections --minify",
        "phx.digest"
      ]
    ]
  end
end
