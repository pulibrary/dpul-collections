defmodule DpulCollectionsWeb.SolrSandboxPlug do
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    user_agent =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [user_agent | _] -> user_agent
        _ -> nil
      end

    DpulCollections.Solr.Sandbox.allow(user_agent)
    conn
  end
end
