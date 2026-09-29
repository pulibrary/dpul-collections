defmodule DpulCollections.Solr.Client do
  alias DpulCollections.Solr.Index

  defmodule ServerError do
    defexception [:message]
  end

  def query(index = %Index{}, options) when is_list(options) do
    Req.post(
      select_url(index),
      options
    )
    |> parse_req_result
  end

  def parse_req_result({:ok, %{status: 200, body: %{"error" => %{"code" => code, "msg" => msg}}}}) do
    raise ServerError, message: "Solr server returned with code: #{code}, message: #{msg}"
  end

  def parse_req_result(response = {:ok, %{status: 200}}) do
    response
  end

  def parse_req_result({:ok, %{status: status}}) do
    raise ServerError, message: "Solr server returned with status code: #{status}"
  end

  def parse_req_result({:error, error}) when is_map_key(error, :reason) do
    raise ServerError, message: "#{error.__struct__}, message: #{error.reason}"
  end

  def parse_req_result({:error, error}) do
    raise ServerError, message: error.__struct__
  end

  def add(index = %Index{}, docs) when is_list(docs) do
    Req.post(
      update_url(index),
      json: docs
    )
    |> parse_req_result
  end

  def add(index = %Index{}, doc), do: add(index, [doc])

  def commit(index = %Index{}) do
    Req.get(
      update_url(index),
      params: [commit: true]
    )
  end

  def soft_commit(index = %Index{}) do
    Req.get(
      update_url(index),
      params: [commit: true, softCommit: true]
    )
  end

  def delete_all(index = %Index{}) do
    Req.post(
      update_url(index),
      json: %{delete: %{query: "*:*"}}
    )
    |> parse_req_result
  end

  def delete_ids(index = %Index{}, ids) do
    ids
    |> Enum.each(fn id ->
      Req.post(
        update_url(index),
        json: %{delete: %{query: "id:#{id}"}}
      )
      |> parse_req_result
    end)
  end

  def status(index = %Index{}) do
    Index.connect(index)
    |> Req.merge(url: "/solr/admin/cores?action=STATUS")
    |> Req.merge(headers: %{"accept" => ["application/json"]})
    # Add plug option to facilitate http stubbing in tests
    |> Req.merge(Application.get_env(:dpul_collections, :solr_req_options, []))
    |> Req.get()
  end

  defp select_url(index) do
    Index.connect(index)
    |> Req.merge(url: "/solr/:collection/select", path_params: [collection: index.collection])
    |> Req.merge(headers: %{"accept" => ["application/json"]})
    |> Req.merge(headers: %{"content-type" => ["application/json"]})
    |> Req.Request.append_request_steps(trace_body: &trace_body/1)
  end

  # Add POST body to the trace, since it has all the actual query params.
  defp trace_body(request = %{body: body}) when body != nil do
    OpenTelemetry.Tracer.set_attribute(:"http.request.body", IO.iodata_to_binary(body))
    request
  end

  defp trace_body(request), do: request

  defp update_url(index) do
    Index.connect(index)
    |> Req.merge(url: "/solr/:collection/update", path_params: [collection: index.collection])
    |> Req.merge(headers: %{"accept" => ["application/json"]})
  end
end
