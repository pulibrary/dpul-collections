defmodule DpulCollections.Solr do
  @spec document_count() :: integer()
  def document_count do
    {:ok, response } = Req.get(
      Application.fetch_env!(:dpul_collections, :solr)[:url],
      params: [q: "*:*"]
    )
    response.body["response"]["numFound"]
  end

  @spec add(list(map())) :: :ok
  def add(docs) do
    # Something. See docs:
    # https://solr.apache.org/guide/8_4/uploading-data-with-index-handlers.html
    # {:ok, response} =
  end
end
