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

  defp select_url do
    Path.join(Application.fetch_env!(:dpul_collections, :solr)[:url], "select")
  end

  defp update_url do
    Path.join(Application.fetch_env!(:dpul_collections, :solr)[:url], "update")
  end
end
