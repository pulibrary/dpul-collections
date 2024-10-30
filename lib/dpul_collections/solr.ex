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

  @spec query(map()) :: map()
  def query(search_state) do
    solr_params = [
      q: query_param(search_state),
      "q.op": "AND",
      sort: sort_param(search_state),
      rows: search_state[:per_page],
      start: pagination_offset(search_state)
    ]

    {:ok, response} =
      Req.get(
        select_url(),
        params: solr_params
      )

    response.body["response"]
  end

  defp query_param(search_state) do
    Enum.reject([search_state[:q], date_query(search_state)], &is_nil(&1))
    |> Enum.join(" ")
  end

  defp date_query(%{date_from: nil, date_to: nil}), do: nil

  defp date_query(%{date_from: date_from, date_to: date_to}) do
    from = date_from || "*"
    to = date_to || "*"
    "years_is:[#{from} TO #{to}]"
  end

  defp sort_param(%{sort_by: sort_by}) do
    case sort_by do
      :relevance -> "score desc"
      :date_desc -> "years_is desc"
      :date_asc -> "years_is asc"
    end
  end

  defp pagination_offset(%{page: page, per_page: per_page}) do
    max(page - 1, 0) * per_page
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

  @spec add(list(map()), String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def add(docs, collection \\ nil) do
    Req.post(
      update_url(collection),
      json: docs
    )
  end

  @spec commit(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def commit(collection \\ nil) do
    Req.get(
      update_url(collection),
      params: [commit: true]
    )
  end

  @spec delete_all(String.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_all(collection \\ nil) do
    Req.post!(
      update_url(collection),
      json: %{delete: %{query: "*:*"}}
    )

    commit(collection)
  end

  defp auth(%{username: ""}), do: nil

  defp auth(%{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
  end

  defp select_url do
    client(:read)
    |> Req.merge(url: "/select")
  end

  defp update_url(nil) do
    url_hash = Application.fetch_env!(:dpul_collections, :solr)
    update_url(url_hash[:read_collection])
  end

  defp update_url(collection) do
    client(:write, collection)
    |> Req.merge(url: "/update")
  end

  def client(:read) do
    url_hash = Application.fetch_env!(:dpul_collections, :solr)

    url =
      url_hash[:base_url]
      |> Path.join("solr/#{url_hash[:read_collection]}")

    Req.new(
      base_url: url,
      auth: auth(url_hash)
    )
  end

  def client(:write, collection) do
    url_hash = Application.fetch_env!(:dpul_collections, :solr)

    url =
      url_hash[:base_url]
      |> Path.join("solr/#{collection}")

    Req.new(
      base_url: url,
      auth: auth(url_hash)
    )
  end
end
