ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.Repo, :manual)

Application.put_env(:phoenix_test, :base_url, DpulCollectionsWeb.Endpoint.url())
