DpulCollections.Repo.truncate_all()
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.Repo, :manual)

Application.put_env(:phoenix_test, :base_url, DpulCollectionsWeb.Endpoint.url())
