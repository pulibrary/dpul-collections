defmodule DpulCollections.Solr.Index do
  @enforce_keys [:base_url, :collection]
  defstruct [
    :base_url,
    :cache_version,
    :collection,
    :config_set,
    :username,
    :password,
    :sandbox_key
  ]

  def connect(index = %__MODULE__{base_url: base_url}) do
    Req.new(
      base_url: base_url,
      auth: auth(index)
    )
    |> sandbox(index)
  end

  defp sandbox(req, %{sandbox_key: nil}), do: req
  defp sandbox(req, %{sandbox_key: sandbox_key}) do
    req
    |> Req.merge(params: [solr_sandbox_key: sandbox_key])
    |> Req.merge(params: [processor: "template", "template.field": "solr_sandbox_key_s:#{sandbox_key}"])
  end

  defp auth(%{username: ""}), do: nil
  defp auth(%{username: nil}), do: nil

  defp auth(%{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
  end

  def read_index() do
    struct(__MODULE__, Application.fetch_env!(:dpul_collections, :solr_config)[:read] |> Map.put(:sandbox_key, ProcessTree.get(:solr_sandbox_key)))
  end

  def write_indexes() do
    Application.fetch_env!(:dpul_collections, :solr_config)[:write]
    |> Enum.map(&struct(__MODULE__, &1))
  end
end
