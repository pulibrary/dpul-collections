defmodule DpulCollections.Solr do
  # @spec document_count() :: integer()
  def document_count(collection \\ read_collection()) do
    {:ok, response} =
      Req.get(
        select_url(collection),
        params: [q: "*:*"]
      )

    response.body["response"]["numFound"]
  end

  @query_field_list [
    "id",
    "title_ss",
    "display_date_s",
    "page_count_i",
    "detectlang_ss",
    "slug_s"
  ]

  @spec query(map()) :: map()
  def query(search_state, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      q: query_param(search_state),
      "q.op": "AND",
      fl: fl,
      sort: sort_param(search_state),
      rows: search_state[:per_page],
      start: pagination_offset(search_state)
    ]

    {:ok, response} =
      Req.get(
        select_url(collection),
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

  def latest_document(collection \\ read_collection()) do
    {:ok, response} =
      Req.get(
        select_url(collection),
        params: [q: "*:*", sort: "_version_ desc"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc | _tail] -> doc
    end
  end

  def find_by_id(id, collection \\ read_collection()) do
    {:ok, response} =
      Req.get(
        select_url(collection),
        params: [q: "id:#{id}"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc] -> doc
    end
  end

  @spec add(list(map()), String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def add(docs, collection \\ read_collection()) do
    Req.post(
      update_url(collection),
      json: docs
    )
  end

  @spec commit(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def commit(collection \\ read_collection()) do
    Req.get(
      update_url(collection),
      params: [commit: true]
    )
  end

  @spec delete_all(String.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_all(collection \\ read_collection()) do
    Req.post!(
      update_url(collection),
      json: %{delete: %{query: "*:*"}}
    )

    commit(collection)
  end

  defp select_url(collection) do
    client()
    |> Req.merge(url: "/solr/#{collection}/select")
  end

  defp update_url(collection) do
    client()
    |> Req.merge(url: "/solr/#{collection}/update")
  end

  def client() do
    url_hash = Application.fetch_env!(:dpul_collections, :solr)

    Req.new(
      base_url: url_hash[:base_url],
      auth: auth(url_hash)
    )
  end

  defp auth(%{username: ""}), do: nil

  defp auth(%{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
  end

  def read_collection() do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end

  def config_set() do
    Application.fetch_env!(:dpul_collections, :solr)[:config_set]
  end

  ####
  # Solr management api wrappers
  ####
  def list_collections do
    {:ok, response} =
      client()
      |> Req.merge(url: "/api/collections")
      |> Req.get()

    response.body["collections"]
  end

  def collection_exists?(collection) do
    collection in list_collections()
  end

  def create_collection(collection) do
    client()
    |> Req.merge(url: "/api/collections")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(
      json: %{
        create: %{
          name: collection,
          config: config_set(),
          numShards: 1,
          waitForFinalState: true
        }
      }
    )
  end

  def delete_collection(collection) do
    client()
    |> Req.merge(url: "api/collections/#{collection}")
    |> Req.delete!()
  end

  def get_alias do
    {:ok, response} =
      client()
      |> Req.merge(
        url: "solr/admin/collections",
        params: [action: "LISTALIASES"]
      )
      |> Req.get()

    response.body["aliases"][read_collection()]
  end

  def set_alias(collection) do
    client()
    |> Req.merge(url: "api/c")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(json: %{"create-alias": %{name: read_collection(), collections: [collection]}})
  end

  def document_count_report do
    Application.fetch_env!(:dpul_collections, DpulCollections.IndexingPipeline)
    |> Enum.map(fn kwl ->
      %{
        cache_version: kwl[:cache_version],
        collection: kwl[:write_collection],
        document_count: document_count(kwl[:write_collection])
      }
    end)
  end
end
