defmodule DpulCollections.DurableServer.EctoStore do
  @moduledoc """
  A DurableServer storage backend that persists state to PostgreSQL via Ecto.

  Uses Ecto's built-in optimistic locking for CAS operations.

  ## Options

    * `:repo` - (required) The Ecto.Repo module to use

  """

  @behaviour DurableServer.StorageBackend

  alias DpulCollections.DurableServer.EctoStore.Object
  alias DurableServer.StoredState

  import Ecto.Query

  @valid_state_opts [:repo, :timeout]

  @type state :: %{
          required(:repo) => module()
        }

  def normalize_opts(opts) when is_list(opts) do
    opts = Keyword.validate!(opts, @valid_state_opts)
    repo = Keyword.fetch!(opts, :repo)

    unless is_atom(repo) do
      raise ArgumentError, "Ecto backend :repo must be a module, got: #{inspect(repo)}"
    end

    %{repo: repo}
  end

  @impl true
  def init_backend(opts) when is_map(opts), do: opts |> Map.to_list() |> init_backend()

  def init_backend(opts) when is_list(opts) do
    {:ok,
     %{
       state: normalize_opts(opts),
       defaults: %{
         heartbeat_tracking_mode: :poll,
         discovery_interval_ms: 3_000,
         heartbeat_interval_ms: 10_000,
         heartbeat_reconcile_interval_ms: 30_000
       },
       features: %{
         heartbeat_subscribe?: false,
         list_includes_body?: true
       }
     }}
  end

  @impl true
  def ensure_ready(%{repo: repo} = _state) do
    try do
      repo.query!("SELECT 1 FROM durable_server_objects LIMIT 0")
      :ok
    rescue
      _error -> {:error, :repo_not_ready}
    end
  end

  @impl true
  def get_object(%{repo: repo} = _state, key, _opts) when is_binary(key) do
    case repo.get(Object, key) do
      nil ->
        {:error, :not_found}

      %Object{body: body, version: version} ->
        with {:ok, decoded} <- decode_body(body) do
          {:ok, %{body: decoded, etag: Integer.to_string(version)}}
        end
    end
  end

  @impl true
  def list_all_objects_stream(%{repo: repo} = _state, prefix, opts) when is_binary(prefix) do
    {error_handler, _stream_opts} =
      Keyword.pop(opts, :error_handler, fn reason -> raise inspect(reason) end)

    query =
      from(o in Object,
        where: like(o.key, ^"#{prefix}%"),
        order_by: [asc: o.key]
      )

    page_size = 500

    # Need to page through postgres basically.
    try do
      Stream.unfold(:start, fn
        :done ->
          nil

        cursor ->
          page_query =
            case cursor do
              :start -> query |> limit(^page_size)
              last_key -> query |> where([o], o.key > ^last_key) |> limit(^page_size)
            end

          case repo.all(page_query) do
            [] ->
              nil

            rows ->
              next_cursor =
                if length(rows) < page_size, do: :done, else: List.last(rows).key

              {rows, next_cursor}
          end
      end)
      |> Stream.flat_map(& &1)
      |> Stream.map(fn %Object{key: key, body: body, version: version} ->
        case decode_body(body) do
          {:ok, decoded} ->
            %{key: key, etag: Integer.to_string(version), body: decoded}

          {:error, reason} ->
            case error_handler.({:decode_failed, key, reason}) do
              :halt -> throw(:halt_stream)
              _ -> nil
            end
        end
      end)
      |> Stream.reject(&is_nil/1)
    rescue
      error ->
        case error_handler.(error) do
          _ -> Stream.map([], & &1)
        end
    end
  end

  @impl true
  def put_object(%{repo: repo} = _state, key, data, opts) when is_binary(key) do
    with {:ok, encoded} <- encode_body(data) do
      case Keyword.fetch(opts, :etag) do
        {:ok, etag} ->
          put_with_cas(repo, key, encoded, data, etag)

        :error ->
          put_unconditional(repo, key, encoded, data)
      end
    end
  end

  @impl true
  def delete_object(%{repo: repo} = _state, key) when is_binary(key) do
    case repo.get(Object, key) do
      nil -> {:error, :not_found}
      object -> repo.delete(object) && :ok
    end
  end

  @impl true
  def try_claim(%{repo: repo} = _state, key, body) when is_binary(key) do
    with {:ok, encoded} <- encode_body(body) do
      changeset =
        Object.changeset(%Object{}, %{key: key, body: encoded})
        |> Ecto.Changeset.unique_constraint(:key, name: :durable_server_objects_pkey)

      case repo.insert(changeset) do
        {:ok, %Object{version: version}} ->
          {:ok, {:claimed, Integer.to_string(version)}}

        {:error, %Ecto.Changeset{errors: [key: _]}} ->
          {:error, :already_claimed}
      end
    end
  end

  @impl true
  def update_object(%{} = state, key, update_fn, _opts)
      when is_binary(key) and is_function(update_fn, 1) do
    case get_object(state, key, []) do
      {:ok, %{body: body, etag: etag}} ->
        case update_fn.(%{body: body, etag: etag}) do
          {:ok, new_data} ->
            put_object(state, key, new_data, etag: etag)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def encode(%{} = _state, data), do: encode_body(data)

  @impl true
  def decode(%{} = _state, data), do: decode_body(data)

  defp put_unconditional(repo, key, encoded, data) do
    changeset = Object.changeset(%Object{}, %{key: key, body: encoded})

    case repo.insert(changeset,
           on_conflict: [set: [body: encoded, version: dynamic([o], o.version + 1)]],
           conflict_target: :key,
           returning: [:version]
         ) do
      {:ok, %Object{version: version}} ->
        {:ok, %{etag: Integer.to_string(version), body: data}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # CAS is apparently "change and switch" - basically guarded upsert I guess?
  defp put_with_cas(repo, key, encoded, data, etag) do
    case Integer.parse(etag) do
      {expected_version, ""} ->
        # Build a struct with the expected version so optimistic_lock
        # generates WHERE version = expected_version.
        object = %Object{key: key, version: expected_version}
        changeset = Object.update_changeset(object, %{body: encoded})

        case repo.update(changeset) do
          {:ok, %Object{version: new_version}} ->
            {:ok, %{etag: Integer.to_string(new_version), body: data}}

          {:error, %Ecto.Changeset{}} ->
            {:error, :conflict}
        end

      _ ->
        {:error, :conflict}
    end
  rescue
    Ecto.StaleEntryError -> {:error, :conflict}
  end

  defp encode_body(%StoredState{} = stored_state) do
    {:ok, StoredState.to_object_store_term(stored_state)}
  rescue
    error in [ArgumentError, RuntimeError] -> {:error, error}
  end

  defp encode_body(data), do: {:ok, data}

  defp decode_body(data) when is_map(data) do
    case StoredState.from_object_store_term(data) do
      {:ok, stored_state} -> {:ok, stored_state}
      :not_stored_state -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp decode_body(data), do: {:ok, data}
end
