defmodule DpulCollections.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DpulCollectionsWeb.Telemetry,
      DpulCollections.Repo,
      DpulCollections.FiggyRepo,
      {DNSCluster, query: Application.get_env(:dpul_collections, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DpulCollections.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DpulCollections.Finch},
      # Start a worker by calling: DpulCollections.Worker.start_link(arg)
      # {DpulCollections.Worker, arg},
      # Start to serve requests, typically the last entry
      DpulCollectionsWeb.Endpoint
    ] ++ environment_children(Mix.env)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DpulCollections.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def environment_children(:test) do
    []
  end

  # coveralls-ignore-start
  def environment_children(_) do
    if Phoenix.Endpoint.server?(:dpul_collections, DpulCollectionsWeb.Endpoint) do
      [
        {DpulCollections.IndexingPipeline.Figgy.IndexingConsumer, cache_version: 0, batch_size: 50},
        {DpulCollections.IndexingPipeline.Figgy.TransformationConsumer,cache_version: 0, batch_size: 50},
        {DpulCollections.IndexingPipeline.Figgy.HydrationConsumer,cache_version: 0, batch_size: 50}
      ]
    else
      []
    end
  end
  # coveralls-ignore-end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  # coveralls-ignore-start
  def config_change(changed, _new, removed) do
    DpulCollectionsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
  # coveralls-ignore-end
end
