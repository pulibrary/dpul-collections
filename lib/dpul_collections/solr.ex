defmodule DpulCollections.Solr do
  require Logger

  @spec document_count(String.t()) :: integer()
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
    "slug_s",
    "image_service_urls_ss",
    "primary_thumbnail_service_url_s"
  ]

  @spec query(map(), String.t()) :: map()
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

  def recently_digitized(count, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      fl: fl,
      rows: count,
      sort: "digitized_at_dt desc"
    ]

    {:ok, response} =
      Req.get(
        select_url(collection),
        params: solr_params
      )

    response.body["response"]
  end

  def random(count, seed, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      fl: fl,
      rows: count,
      sort: "random_#{seed} desc"
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

  @spec latest_document(String.t()) :: map()
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

  @spec find_by_id(String.t(), String.t()) :: map()
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

  @spec add(list(map()) | String.t(), String.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def add(docs, collection \\ read_collection())

  def add(docs, collection) when is_list(docs) do
    response =
      Req.post!(
        update_url(collection),
        json: docs
      )

    if response.status != 200 do
      docs |> Enum.each(&add/1)
    end

    response
  end

  def add(doc, collection) when not is_list(doc) do
    response =
      Req.post!(
        update_url(collection),
        json: [doc]
      )

    if response.status != 200 do
      Logger.warning("error indexing solr document with id: #{doc["id"]} #{response.body}")
    end

    response
  end

  @spec commit(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def commit(collection \\ read_collection()) do
    Req.get(
      update_url(collection),
      params: [commit: true]
    )
  end

  @spec soft_commit(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def soft_commit(collection \\ read_collection()) do
    Req.get(
      update_url(collection),
      params: [commit: true, softCommit: true]
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

  @spec delete_batch(list(), String.t()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_batch(ids, collection \\ read_collection()) do
    ids
    |> Enum.each(fn id ->
      Req.post!(
        update_url(collection),
        json: %{delete: %{query: "id:#{id}"}}
      )
    end)

    soft_commit(collection)
  end

  defp select_url(collection) do
    client()
    |> Req.merge(url: "/solr/#{collection}/select")
  end

  defp update_url(collection) do
    client()
    |> Req.merge(url: "/solr/#{collection}/update")
  end

  @spec client() :: Req.Request.t()
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

  @spec read_collection() :: String.t()
  def read_collection() do
    Application.fetch_env!(:dpul_collections, :solr)[:read_collection]
  end

  @spec config_set() :: String.t()
  def config_set() do
    Application.fetch_env!(:dpul_collections, :solr)[:config_set]
  end

  ####
  # Solr management api wrappers
  ####
  @spec list_collections() :: list(String.t())
  def list_collections() do
    {:ok, response} =
      client()
      |> Req.merge(url: "/api/collections")
      |> Req.get()

    response.body["collections"]
  end

  @spec collection_exists?(String.t()) :: boolean()
  def collection_exists?(collection) do
    collection in list_collections()
  end

  @spec create_collection(String.t()) :: Req.Response.t()
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

  @spec delete_collection(String.t()) :: Req.Response.t()
  def delete_collection(collection) do
    client()
    |> Req.merge(url: "api/collections/#{collection}")
    |> Req.delete!()
  end

  @spec get_alias() :: String.t()
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

  @spec set_alias(String.t()) :: Req.Response.t()
  def set_alias(collection) do
    client()
    |> Req.merge(url: "api/c")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(json: %{"create-alias": %{name: read_collection(), collections: [collection]}})
  end
end
