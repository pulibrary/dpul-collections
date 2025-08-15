defmodule DpulCollections.Solr.Management do
  alias DpulCollections.Solr.Index
  alias DpulCollections.Solr
  ####
  # Solr management api wrappers
  ####
  @spec list_collections(%Index{}) :: list(String.t())
  def list_collections(index = %Index{}) do
    {:ok, response} =
      index
      |> Index.connect()
      |> Req.merge(url: "/api/collections")
      |> Req.get()

    response.body["collections"]
  end

  @spec collection_exists?(%Index{}) :: boolean()
  def collection_exists?(index = %Index{}) do
    index.collection in list_collections(index)
  end

  @spec create_collection(%Index{}) :: Req.Response.t()
  def create_collection(index = %Index{}) do
    index
    |> Index.connect()
    |> Req.merge(url: "/api/collections")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(
      json: %{
        create: %{
          name: index.collection,
          config: index.config_set,
          numShards: 1,
          waitForFinalState: true
        }
      }
    )
  end

  @spec delete_collection(%Index{}) :: Req.Response.t()
  def delete_collection(index = %Index{}) do
    index
    |> Index.connect()
    |> Req.merge(url: "api/collections/#{index.collection}")
    |> Req.delete!()
  end

  @spec get_alias(%Index{}) :: String.t()
  def get_alias(index = %Index{}) do
    {:ok, response} =
      index
      |> Index.connect()
      |> Req.merge(
        url: "solr/admin/collections",
        params: [action: "LISTALIASES"]
      )
      |> Req.get()

    response.body["aliases"][Solr.read_collection()]
  end

  @spec set_alias(%Index{}, String.t()) :: Req.Response.t()
  def set_alias(index = %Index{}, alias) do
    index
    |> Index.connect()
    |> Req.merge(url: "api/c")
    |> Req.Request.put_header("content-type", "application/json")
    |> Req.post!(json: %{"create-alias": %{name: alias, collections: [index.collection]}})
  end
end
