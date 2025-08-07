defmodule DpulCollections.Solr do
  require Logger
  use DpulCollections.Solr.Constants

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
    "file_count_i",
    "detectlang_ss",
    "slug_s",
    "image_service_urls_ss",
    "image_canvas_ids_ss",
    "primary_thumbnail_service_url_s",
    "digitized_at_dt",
    "genre_txtm",
    "updated_at_dt",
    "content_warning_s"
  ]

  @spec query(map(), String.t()) :: map()
  def query(search_state, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      q: query_param(search_state),
      # https://solr.apache.org/docs/9_4_0/core/org/apache/solr/util/doc-files/min-should-match.html
      # If more than 6 clauses, only require 90%. Pulled from our catalog.
      mm: "6<90%",
      fq: filter_param(search_state),
      fl: fl,
      sort: sort_param(search_state),
      rows: search_state[:per_page],
      start: pagination_offset(search_state),
      # To do MLT in edismax we have to allow the keyword _query_
      uf: "* _query_"
    ]

    {:ok, response} =
      Req.get(
        select_url(collection),
        params: solr_params
      )

    response.body["response"]
  end

  # Uses the more like this query parser
  # see: https://solr.apache.org/guide/solr/latest/query-guide/morelikethis.html#morelikethis-query-parser
  def related_items(%{id: id}, search_state, rows \\ 5, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      fl: fl,
      q: mlt_query(id),
      rows: rows,
      indent: false,
      fq: filter_param(search_state),
      mm: 1
    ]

    {:ok, response} =
      Req.get(
        query_url(collection),
        params: solr_params
      )

    response.body["response"]
  end

  def mlt_query(id) do
    "{!mlt qf=genre_txtm,subject_txtm,geo_subject_txtm,geographic_origin_txtm,language_txtm,keywords_txtm,description_txtm mintf=1}#{id}"
  end

  def recently_updated(count, collection \\ read_collection()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params = [
      fl: fl,
      rows: count,
      sort: "updated_at_dt desc",
      fq: "file_count_i:[1 TO *]"
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
    [mlt_focus(search_state), search_state[:q]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  def mlt_focus(%{filter: %{"similar" => id}}) do
    mlt_query(id)
  end

  def mlt_focus(_search_state) do
    nil
  end

  def filter_param(search_state) do
    search_state.filter
    |> Enum.map(&generate_filter_query/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  # Simple string filter
  # Negation filter
  def generate_filter_query({_filter_key, "-"}), do: nil

  def generate_filter_query({filter_key, "-" <> filter_value})
      when is_binary(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    "-filter(#{solr_field}:\"#{filter_value}\")"
  end

  # Similar filter - display, but handle in the q parameter instead.
  def generate_filter_query({"similar", _filter_value}) do
    nil
  end

  # Inclusion filter
  def generate_filter_query({filter_key, filter_value})
      when is_binary(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    "+filter(#{solr_field}:\"#{filter_value}\")"
  end

  # Range filter.
  def generate_filter_query({filter_key, filter_value = %{}}) when filter_key in @filter_keys do
    from = filter_value["from"] || "*"
    to = filter_value["to"] || "*"
    solr_field = @filters[filter_key].solr_field
    "+filter(#{solr_field}:[#{from} TO #{to}])"
  end

  def generate_filter_query(_), do: nil

  defp sort_param(%{sort_by: sort_by}) do
    @valid_sort_by[sort_by][:solr_param]
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

  defp query_url(collection) do
    client()
    |> Req.merge(url: "/solr/#{collection}/query")
  end

  @spec client() :: Req.Request.t()
  def client() do
    url_hash = solr_config()

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
    solr_config()[:read_collection]
  end

  @spec config_set() :: String.t()
  def config_set() do
    solr_config()[:config_set]
  end

  def solr_config() do
    default_value = Application.fetch_env!(:dpul_collections, :solr)
    ProcessTree.get(:dpul_collections_solr, default: default_value)
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

  def delete_alias(alias) do
    {:ok, response} =
      client()
      |> Req.merge(
        url: "solr/admin/collections",
        params: [action: "DELETEALIAS", name: alias]
      )
      |> Req.get()
  end

  @spec set_alias(String.t()) :: Req.Response.t()
  def set_alias(collection) do
    client()
    |> Req.merge(url: "api/c")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(json: %{"create-alias": %{name: read_collection(), collections: [collection]}})
  end
end
