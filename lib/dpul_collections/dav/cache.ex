defmodule DpulCollections.Dav.Cache do
  @moduledoc """
  Tiny ETS-backed cache for the WebDAV prototype.

  WebDAV clients (Finder especially) re-request the same directory listings
  constantly, so listings are memoized for a short TTL. Image byte sizes are
  remembered after the first download so later listings can report them.

  Prototype caveat: entries are never evicted, only expired on read.
  """
  use GenServer

  @table __MODULE__

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, nil}
  end

  @doc "Return the cached value for `key`, computing it with `fun` when missing or stale."
  def fetch(key, fun) do
    ttl = Application.get_env(:dpul_collections, :dav_cache_ttl_ms, :timer.minutes(10))
    now = System.monotonic_time(:millisecond)

    case lookup(key) do
      {value, expires} when expires > now ->
        value

      _ ->
        value = fun.()
        if ttl > 0, do: :ets.insert(@table, {key, value, now + ttl})
        value
    end
  end

  def put_size(url, bytes), do: :ets.insert(@table, {{:size, url}, bytes, :infinity})

  def size(url) do
    case lookup({:size, url}) do
      {bytes, _} -> bytes
      nil -> nil
    end
  end

  defp lookup(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires}] -> {value, expires}
      [] -> nil
    end
  end
end
