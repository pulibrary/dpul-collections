defmodule DpulCollections.Solr.Index do
  @enforce_keys [:base_url]
  defstruct [
    :cache_version,
    :base_url,
    :collection,
    :config_set,
    :username,
    :password
  ]

  def connect(index = %__MODULE__{base_url: base_url, username: _username, password: _password}) do
    Req.new(
      base_url: base_url,
      auth: auth(index)
    )
  end

  def connect(%__MODULE__{base_url: base_url}) do
    Req.new(
      base_url: base_url
    )
  end

  defp auth(%{username: ""}), do: nil

  defp auth(%{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
  end

  def read_index() do
    struct(__MODULE__, Application.fetch_env!(:dpul_collections, :solr_config)[:read])
  end

  def write_indexes() do
    Application.fetch_env!(:dpul_collections, :solr_config)[:write]
    |> Enum.map(&struct(__MODULE__, &1))
  end
end
