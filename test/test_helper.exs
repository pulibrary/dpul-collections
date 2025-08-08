ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.FiggyRepo, :manual)

defmodule BroadwayEctoSandbox do
  def attach(repo) do
    events = [
      [:database_producer, :startup],
      [:broadway, :processor, :start],
      [:broadway, :batch_processor, :start],
      [:dpulc, :indexing_pipeline, :transformer, :time_to_poll],
      [:dpulc, :indexing_pipeline, :hydrator, :time_to_poll],
      [:dpulc, :indexing_pipeline, :indexer, :time_to_poll]
    ]

    :telemetry.attach_many({__MODULE__, repo}, events, &__MODULE__.handle_event/4, %{repo: repo})
  end

  def handle_event(
        _event_name,
        _event_measurement,
        %{extra_metadata: %{ecto_pid: pid}},
        %{repo: repo}
      ) do
    Ecto.Adapters.SQL.Sandbox.allow(repo, pid, self())
    :ok
  end

  def handle_event(
        _event_name,
        _event_measurement,
        %{extra_metadata: _},
        %{repo: _}
      ) do
    :ok
  end

  def handle_event(_event_name, _event_measurement, %{messages: messages}, %{repo: repo}) do
    with [%Broadway.Message{metadata: %{ecto_pid: pid}} | _] <- messages do
      Ecto.Adapters.SQL.Sandbox.allow(repo, pid, self())
    end

    :ok
  end
end

BroadwayEctoSandbox.attach(DpulCollections.Repo)
BroadwayEctoSandbox.attach(DpulCollections.FiggyRepo)

Application.put_env(:phoenix_test, :base_url, DpulCollectionsWeb.Endpoint.url())
