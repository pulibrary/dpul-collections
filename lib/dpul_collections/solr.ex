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

  def query(%{q: q, sort_by: sort_by}) do
    params = [
      q: q,
      sort: sort_param(sort_by)
    ]

    {:ok, response} =
      Req.get(
        select_url(),
        params: params
      )

    response.body["response"]["docs"]
  end

  defp sort_param(sort_by_value) do
    case sort_by_value do
      :relevance -> "score desc"
      :id -> "id desc"
    end
  end

  def latest_document() do
    {:ok, response} =
      Req.get(
        select_url(),
        params: [q: "*:*", sort: "_version_ desc"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc | _tail] -> doc
    end
  end

  def find_by_id(id) do
    {:ok, response} =
      Req.get(
        select_url(),
        params: [q: "id:#{id}"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc] -> doc
    end
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
    url_hash = Application.fetch_env!(:dpul_collections, :solr)

    Req.new(
      base_url: url_hash[:url],
      auth: auth(url_hash)
    )
  end

  defp auth(%{username: ""}), do: nil

  defp auth(%{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
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
