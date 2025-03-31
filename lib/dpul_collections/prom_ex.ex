defmodule DpulCollections.PromEx do
  @moduledoc """
  4. Update the list of plugins in the `plugins/0` function return list to reflect your
     application's dependencies. Also update the list of dashboards that are to be uploaded
     to Grafana in the `dashboards/0` function.
  """

  use PromEx, otp_app: :dpul_collections

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # PromEx built in plugins
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: DpulCollectionsWeb.Router, endpoint: DpulCollectionsWeb.Endpoint},
      {Plugins.Ecto, repos: [DpulCollections.Repo, DpulCollections.FiggyRepo]},
      # Plugins.Oban,
      Plugins.PhoenixLiveView,
      # Plugins.Absinthe,
      Plugins.Broadway

      # Add your own PromEx metrics plugins
      # DpulCollections.Users.PromExPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "nomad_prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # PromEx built in Grafana dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      # {:prom_ex, "oban.json"},
      {:prom_ex, "phoenix_live_view.json"},
      # {:prom_ex, "absinthe.json"},
      {:prom_ex, "broadway.json"}

      # Add your dashboard definitions here with the format: {:otp_app, "path_in_priv"}
      # {:dpul_collections, "/grafana_dashboards/user_metrics.json"}
    ]
  end
end
