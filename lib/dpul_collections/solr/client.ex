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

  def parse_req_result(response = {:ok, %{status: 200}}) do
    response
  end

  def parse_req_result({:error, %Req.TransportError{reason: reason}}) do
    raise ServerError, message: "Req TransportError, reason: #{reason}"
  end

  def parse_req_result({:ok, %{status: status, body: body}}) do
    raise ServerError, message: "Solr server returned with status code: #{status}, body #{body}"
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

  def delete_all(index = %Index{sandbox_key: sandbox_key}) do
    query =
      if is_binary(sandbox_key) do
        "solr_sandbox_key_s:#{sandbox_key}"
      else
        "*:*"
      end

    Req.post(
      update_url(index),
      json: %{delete: %{query: query}}
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

  defp select_url(index = %Index{}) do
    Index.connect(index)
    |> Req.merge(url: "/solr/#{index.collection}/select")
    |> Req.merge(headers: %{"accept" => ["application/json"]})
    |> Req.merge(headers: %{"content-type" => ["application/json"]})
    |> sandbox(index)
  end

  defp sandbox(req, index = %Index{sandbox_key: sandbox_key}) when is_binary(sandbox_key) do
    req
    |> Req.merge(params: [fq: "solr_sandbox_key_s:#{index.sandbox_key}"])
  end

  defp sandbox(req, _index), do: req

  defp update_url(index) do
    Index.connect(index)
    |> Req.merge(url: "/solr/#{index.collection}/update")
    |> Req.merge(headers: %{"accept" => ["application/json"]})
  end
end
