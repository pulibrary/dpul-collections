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
