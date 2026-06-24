DpulCollections.Repo.truncate_all()
DpulCollections.Solr.delete_all(SolrTestSupport.active_collection() |> Map.put(:sandbox_key, "all"))
DpulCollections.Solr.commit(SolrTestSupport.active_collection())
ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(DpulCollections.Repo, :manual)

{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
Application.put_env(:phoenix_test, :base_url, DpulCollectionsWeb.Endpoint.url())
