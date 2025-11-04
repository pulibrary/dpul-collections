defmodule DpulCollections.Solr.Client do
  alias DpulCollections.Solr.Index

  defmodule ServerError do
    defexception [:message]
  end

  def query(index = %Index{}, options) when is_list(options) do
    {:ok, response} =
      Req.post(
        select_url(index),
        options
      )

    case response.status do
      200 -> {:ok, response}
      _ -> raise ServerError, message: "Solr server returned with status code: #{response.status}"
    end
  end

  def add(index = %Index{}, docs) when is_list(docs) do
    Req.post(
      update_url(index),
      json: docs
    )
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
    {:ok, response} =
      Req.post(
        update_url(index),
        json: %{delete: %{query: "*:*"}}
      )

    case response.status do
      200 -> {:ok, response}
      _ -> raise ServerError, message: "Solr server returned with status code: #{response.status}"
    end
  end

  def delete_ids(index = %Index{}, ids) do
    ids
    |> Enum.each(fn id ->
      {:ok, response} =
        Req.post(
          update_url(index),
          json: %{delete: %{query: "id:#{id}"}}
        )

      if response.status != 200 do
        raise ServerError, message: "Solr server returned with status code: #{response.status}"
      end
    end)
  end

  defp select_url(index) do
    Index.connect(index)
    |> Req.merge(url: "/solr/#{index.collection}/select")
    |> Req.merge(headers: %{"accept" => ["application/json"]})
    |> Req.merge(headers: %{"content-type" => ["application/json"]})
  end

  defp update_url(index) do
    Index.connect(index)
    |> Req.merge(url: "/solr/#{index.collection}/update")
    |> Req.merge(headers: %{"accept" => ["application/json"]})
  end
end
