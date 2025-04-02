defmodule DpulCollections.MixProject do
  use Mix.Project

  def project do
    [
      app: :dpul_collections,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
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
  # Provide access to TestFiggyProducer in dev.
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.20.0"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, "~> 0.37", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.18"},
      {:finch, "~> 0.19"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.2"},
      {:bandit, "~> 1.6"},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:broadway, "~> 1.2"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:req, "~> 0.5"},
      {:broadway_dashboard, "~> 0.4"},
      {:honeybadger, "~> 0.23"},
      {:phoenix_test_playwright, "~> 0.6", only: :test, runtime: false},
      {:live_debugger, "~> 0.1.4", only: :dev},
      {:prom_ex, "~> 1.11.0"},
      {:ecto_psql_extras, "~> 0.6"},
      # Sibyl adds a decorator that automatically wraps a method and makes it
      # send telemetry events.
      {:sibyl, "~> 0.1.0"},
      # Required to run metrics server
      {:plug_cowboy, "~> 2.0"}
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "assets.build",
        "coveralls.html"
      ],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd npm --prefix assets install",
        "cmd npm --prefix assets exec playwright install chromium --with-deps"
      ],
      "assets.build": ["tailwind dpul_collections", "esbuild dpul_collections"],
      "assets.deploy": [
        "tailwind dpul_collections --minify",
        "esbuild dpul_collections --minify",
        "phx.digest"
      ]
    ]
  end
end
