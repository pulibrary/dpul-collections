defmodule DpulCollections.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        DpulCollectionsWeb.Telemetry,
        DpulCollections.Repo,
        DpulCollections.FiggyRepo,
        {DNSCluster,
         query: Application.get_env(:dpul_collections, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: DpulCollections.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: DpulCollections.Finch},
        # Start a worker by calling: DpulCollections.Worker.start_link(arg)
        # {DpulCollections.Worker, arg},
        # Start to serve requests, typically the last entry
        DpulCollectionsWeb.Endpoint
      ] ++ environment_children(Application.fetch_env!(:dpul_collections, :current_env))

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DpulCollections.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def environment_children(:test) do
    []
  end

  # coveralls-ignore-start
  # In development, start the indexing pipeline when the phoenix server starts.
  def environment_children(:dev) do
    if Phoenix.Endpoint.server?(:dpul_collections, DpulCollectionsWeb.Endpoint) do
      indexing_pipeline_children()
    else
      []
    end
  end

  # In production, start the indexing pipeline if it's configured to be started
  def environment_children(:prod) do
    if Application.fetch_env!(:dpul_collections, :start_indexing_pipeline) == true do
      indexing_pipeline_children()
    else
      []
    end
  end

  def indexing_pipeline_children() do
    for pipeline <- Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline) do
      cache_version = pipeline[:cache_version]
      write_collection = pipeline[:write_collection]

      [
        Supervisor.child_spec(
          {DpulCollections.IndexingPipeline.Figgy.IndexingConsumer,
           cache_version: cache_version, batch_size: 50, write_collection: write_collection},
          id: String.to_atom("figgy_indexer_#{cache_version}")
        ),
        Supervisor.child_spec(
          {DpulCollections.IndexingPipeline.Figgy.TransformationConsumer,
           cache_version: cache_version, batch_size: 50},
          id: String.to_atom("figgy_transformer_#{cache_version}")
        ),
        Supervisor.child_spec(
          {DpulCollections.IndexingPipeline.Figgy.HydrationConsumer,
           cache_version: cache_version, batch_size: 50},
          id: String.to_atom("figgy_hydrator_#{cache_version}")
        )
      ]
    end
    |> List.flatten()
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
