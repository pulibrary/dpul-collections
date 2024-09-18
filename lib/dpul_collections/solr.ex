defmodule DpulCollections.Solr do
  @spec document_count() :: integer()
  def document_count do
    {:ok, response} =
      Req.get(
        select_url(),
        params: [q: "*:*"]
      )

    response.body["response"]["numFound"]
  end

  @spec add(list(map())) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def add(docs) do
    Req.post(
      update_url(),
      json: docs
    )
  end

  @spec commit() :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def commit() do
    Req.get(
      update_url(),
      params: [commit: true]
    )
  end

  @spec delete_all() :: {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_all() do
    Req.post!(
      update_url(),
      json: %{delete: %{query: "*:*"}}
    )

    commit()
  end

  def client() do
    url_hash = url_hash(Application.fetch_env!(:dpul_collections, :solr)[:url])

    Req.new(
      base_url: base_url(url_hash),
      auth: auth(url_hash)
    )
  end

  defp url_hash(url) do
    Regex.named_captures(
      ~r/^(?<protocol>.+?\/\/)((?<username>.+?):(?<password>.+?)@)?(?<address>.+)$/,
      url
    )
  end

  defp auth(%{"username" => ""}), do: nil

  defp auth(%{"username" => username, "password" => password}) do
    {:basic, "#{username}:#{password}"}
  end

  defp base_url(%{"protocol" => protocol, "address" => address}) do
    protocol <> address
  end

  defp select_url do
    client()
    |> Req.merge(url: "/select")
  end

  defp update_url do
    client()
    |> Req.merge(url: "/update")
  end
end
