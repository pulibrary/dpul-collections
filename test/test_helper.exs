ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.FiggyRepo, :manual)

Application.put_env(:phoenix_test, :base_url, DpulCollectionsWeb.Endpoint.url())
