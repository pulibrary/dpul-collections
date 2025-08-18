defmodule DpulCollections.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        DpulCollections.PromEx,
        DpulCollectionsWeb.Telemetry,
        DpulCollections.Repo,
        DpulCollections.FiggyRepo,
        {DNSCluster,
         query: Application.get_env(:dpul_collections, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: DpulCollections.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: DpulCollections.Finch},
        {Oban, Application.fetch_env!(:dpul_collections, Oban)},
        # Start a worker by calling: DpulCollections.Worker.start_link(arg)
        # {DpulCollections.Worker, arg},
        # Start to serve requests, typically the last entry
        DpulCollectionsWeb.Endpoint,
        DpulCollections.IndexMetricsTracker
      ] ++ filter_pipeline_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DpulCollections.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # coveralls-ignore-start
  def filter_pipeline_children() do
    fun = Application.fetch_env!(:dpul_collections, :start_indexing_pipeline?)

    if fun.() == true do
      indexing_pipeline_children()
    else
      []
    end
  end

  def indexing_pipeline_children() do
    for index <- DpulCollections.Solr.Index.write_indexes() do
      cache_version = index.cache_version

      [
        Supervisor.child_spec(
          {DpulCollections.IndexingPipeline.Figgy.IndexingConsumer,
           cache_version: cache_version, batch_size: 50, solr_index: index},
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
