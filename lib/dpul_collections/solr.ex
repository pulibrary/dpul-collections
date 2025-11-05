defmodule DpulCollections.Solr do
  require Logger
  use DpulCollections.Solr.Constants
  alias DpulCollectionsWeb.SearchLive.SearchState
  alias DpulCollections.Solr.Index
  alias DpulCollections.SearchResult
  alias DpulCollections.Solr.Client

  @spec document_count(%Index{}) :: integer()
  def document_count(index \\ Index.read_index()) do
    {:ok, response} =
      Client.query(
        index,
        params: [q: "*:*"]
      )

    response.body["response"]["numFound"]
  end

  def project_summary(label, index \\ Index.read_index()) do
    params =
      %{"per_page" => "0"}
      |> SearchState.from_params()
      |> SearchState.set_filter("project", label)
      |> SearchState.add_filter_count_fields([
        "language",
        "geographic_origin",
        "category",
        "genre"
      ])

    params
    |> raw_query(index)
    |> to_search_result()
  end

  @query_field_list [
    "id",
    "title_ss",
    "display_date_s",
    "file_count_i",
    "detectlang_ss",
    # Solr generates `slug_s` via a script from the title, but users define
    # slugs for collections and projects, so we have to store the slug from the user separately.
    "authoritative_slug_s",
    "resource_type_s",
    "slug_s",
    "image_service_urls_ss",
    "image_canvas_ids_ss",
    "primary_thumbnail_service_url_s",
    "digitized_at_dt",
    "genre_txt_sort",
    "updated_at_dt",
    "content_warning_s",
    "geographic_origin_txt_sort",
    "tagline_txtm"
  ]

  def raw_query(search_state, index \\ Index.read_index()) do
    fl = Enum.join(@query_field_list, ",")

    solr_params =
      [
        q: query_param(search_state),
        # https://solr.apache.org/docs/9_4_0/core/org/apache/solr/util/doc-files/min-should-match.html
        # If more than 6 clauses, only require 90%. Pulled from our catalog.
        mm: "6<90%",
        fl: fl,
        sort: sort_param(search_state),
        rows: search_state[:per_page],
        start: pagination_offset(search_state),
        # To do MLT in edismax we have to allow the keyword _query_
        uf: "* _query_"
      ]
      |> Keyword.merge(filter_count_params(search_state.filter_count_fields))
      |> Keyword.merge(search_state[:extra_params] || [])

    {:ok, response} =
      Client.query(
        index,
        params: solr_params,
        # Send filters in a POST request in case a lot of filters are requested.
        # This uses the JSON Filter API so we can send an array of filters: https://solr.apache.org/guide/solr/latest/query-guide/json-request-api.html
        json: %{
          filter: filter_param(search_state)
        }
      )

    response.body
  end

  defp filter_count_params([]), do: []

  defp filter_count_params(filter_count_fields) do
    facet_params =
      filter_count_fields
      |> Enum.flat_map(fn field ->
        # For every field we request counts for exclude any filters we've set on
        # that field when calculating it (ex=exclude), and name it after our shorthand field (key).
        # See https://solr.apache.org/guide/solr/latest/query-guide/faceting.html#tagging-and-excluding-filters
        case @filters[field] do
          # For range filters don't facet - we'll render custom range boxes.
          %{type: :range} ->
            []

          _ ->
            [{:"facet.field", "{!ex=#{field}Filter key=#{field}}#{@filters[field].solr_field}"}]
        end
      end)

    [
      facet: true,
      "facet.limit": -1,
      "facet.mincount": 1,
      "facet.sort": "count"
    ] ++ facet_params
  end

  @spec query(map(), String.t()) :: map()
  def query(search_state, index \\ Index.read_index()) do
    raw_query(search_state, index)["response"]
  end

  @filter_fields ["project", "genre", "language", "subject", "year"]
  def search(search_state, index \\ Index.read_index()) do
    search_state
    |> SearchState.add_filter_count_fields(@filter_fields)
    |> raw_query(index)
    |> to_search_result()
  end

  defp to_search_result(solr_response) do
    SearchResult.from_solr(solr_response)
  end

  # Uses the more like this query parser
  # see: https://solr.apache.org/guide/solr/latest/query-guide/morelikethis.html#morelikethis-query-parser
  def related_items(%{id: id}, search_state, rows \\ 5, index \\ Index.read_index()) do
    search_state =
      SearchState.from_params(%{
        "filter" =>
          Map.merge(
            search_state.filter,
            %{
              # Similar adds a MoreLikeThis query to the query, to restrict to
              # items like the given id.
              "similar" => id,
              # No collections.
              "resource_type" => "-collection"
            }
          ),
        "per_page" => "#{rows}"
      })
      |> Map.put(:extra_params, mm: 1)

    query(search_state, index)
  end

  def recently_added(
        count,
        search_state \\ SearchState.from_params(%{}),
        index \\ Index.read_index()
      ) do
    search_state =
      SearchState.from_params(%{
        "filter" =>
          Map.merge(
            search_state.filter,
            %{
              # No collections.
              "resource_type" => "-collection",
              # Require at least one image.
              "file_count" => %{"from" => 1}
            }
          ),
        "sort_by" => "recently_added",
        "per_page" => "#{count}"
      })

    query(search_state, index)
  end

  def random(count, seed, index \\ Index.read_index()) do
    search_state =
      SearchState.from_params(%{
        "filter" => %{
          # No collections.
          "resource_type" => "-collection",
          # Require at least one image.
          "file_count" => %{"from" => 1}
        },
        "per_page" => "#{count}"
      })
      # We can't have a sort_by here because it's dynamic by seed, so just put
      # it in directly.
      |> Map.put(:extra_params, sort: "random_#{seed} desc")

    query(search_state, index)
  end

  defp query_param(search_state) do
    [mlt_focus(search_state), search_state[:q]] |> Enum.reject(&is_nil/1) |> Enum.join(" ")
  end

  def mlt_focus(%{filter: %{"similar" => id}}) do
    "{!mlt qf=genre_txt_sort,subject_txt_sort,geo_subject_txt_sort,geographic_origin_txt_sort,language_txt_sort,keywords_txt_sort,description_txtm mintf=1}#{id}"
  end

  def mlt_focus(_search_state) do
    nil
  end

  def filter_param(search_state) do
    search_state.filter
    |> Enum.map(&generate_filter_query/1)
    |> Enum.reject(&is_nil/1)
  end

  # Generate filter queries for requested filters - we tag them with {!tag} so
  # we can filter them out when getting filter counts.
  # Simple string filter
  # Negation filter
  def generate_filter_query({_filter_key, "-"}), do: nil

  def generate_filter_query({filter_key, "-" <> filter_value})
      when is_binary(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    "{!tag=#{filter_key}Filter}-#{solr_field}:\"#{filter_value}\""
  end

  # Similar filter - display, but handle in the q parameter instead.
  def generate_filter_query({"similar", _filter_value}) do
    nil
  end

  # Inclusion filter
  def generate_filter_query({filter_key, filter_value})
      when is_binary(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    "{!tag=#{filter_key}Filter}#{solr_field}:\"#{filter_value}\""
  end

  def generate_filter_query({filter_key, filter_value})
      when is_boolean(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    "{!tag=#{filter_key}Filter}#{solr_field}:#{filter_value}"
  end

  # Inclusion for a list of strings.
  def generate_filter_query({filter_key, values = [filter_value | _]})
      when is_binary(filter_value) and filter_key in @filter_keys do
    solr_field = @filters[filter_key].solr_field
    filter_strings = values |> Enum.map(fn value -> ~s("#{value}") end)
    "{!tag=#{filter_key}Filter}#{solr_field}:(#{filter_strings |> Enum.join("OR ")})"
  end

  # Range filter.
  def generate_filter_query({filter_key, filter_value = %{}}) when filter_key in @filter_keys do
    from = filter_value["from"] || "*"
    to = filter_value["to"] || "*"
    solr_field = @filters[filter_key].solr_field
    "{!tag=#{filter_key}Filter}#{solr_field}:[#{from} TO #{to}]"
  end

  def generate_filter_query(_), do: nil

  defp sort_param(%{sort_by: sort_by}) do
    @valid_sort_by[sort_by][:solr_param]
  end

  defp pagination_offset(%{page: page, per_page: per_page}) do
    max(page - 1, 0) * per_page
  end

  @spec latest_document(String.t()) :: map()
  def latest_document(index \\ Index.read_index()) do
    {:ok, response} =
      Client.query(
        index,
        params: [q: "*:*", sort: "_version_ desc"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc | _tail] -> doc
    end
  end

  @spec find_by_id(String.t(), String.t()) :: map()
  def find_by_id(id, index \\ Index.read_index())

  def find_by_id(nil, _index), do: nil
  def find_by_id("", _index), do: nil

  def find_by_id(id, index) do
    {:ok, response} =
      Client.query(
        index,
        params: [q: "id:#{id}"]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc] -> doc
    end
  end

  def find_by_slug(slug, index \\ Index.read_index()) do
    {:ok, response} =
      Client.query(
        index,
        params: [q: "authoritative_slug_s:#{slug}", rows: 1]
      )

    case response.body["response"]["docs"] do
      [] -> nil
      [doc] -> doc
    end
  end

  @spec add(list(map()) | String.t(), %Index{}) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def add(docs, index \\ Index.read_index())

  def add(docs, index) when is_list(docs) do
    {:ok, response} =
      Client.add(index, docs)

    if response.status != 200 do
      docs |> Enum.each(&add/1)
    end

    response
  end

  def add(doc, index) when not is_list(doc) do
    {:ok, response} =
      Client.add(index, doc)

    if response.status != 200 do
      Logger.warning("error indexing solr document with id: #{doc["id"]} #{response.body}")
    end

    response
  end

  @spec commit(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def commit(index \\ Index.read_index()) do
    Client.commit(index)
  end

  @spec soft_commit() :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def soft_commit(index \\ Index.read_index()) do
    Client.soft_commit(index)
  end

  @spec delete_all(%Index{}) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_all(index \\ Index.read_index()) do
    {:ok, _} = Client.delete_all(index)
    soft_commit(index)
  end

  @spec delete_batch(list(), %Index{}) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()} | Exception.t()
  def delete_batch(ids, index \\ Index.read_index()) do
    Client.delete_ids(index, ids)
    soft_commit(index)
  end
end
