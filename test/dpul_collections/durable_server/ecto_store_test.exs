defmodule DpulCollections.DurableServer.EctoStoreTest do
  use DpulCollections.DataCase, async: false

  alias DpulCollections.DurableServer.EctoStore
  alias DurableServer.StorageBackend
  alias DurableServer.StoredState
  alias DpulCollections.Repo
  alias DurableServer.TestCounterServer, as: CounterServer
  @moduletag :capture_log
  ## Most of these tests pulled from https://github.com/phoenixframework/durable_server/blob/main/test/ekv_integration_test.exs

  setup do
    unique_id = System.unique_integer([:positive, :monotonic])

    supervisor_name = :"durable_ecto_supervisor_#{unique_id}"
    prefix = "ecto_integration/#{unique_id}/"

    start_supervised!(
      {DurableServer.Supervisor,
       [
         name: supervisor_name,
         prefix: prefix,
         backend: {EctoStore, [repo: Repo]},
         graceful_shutdown_timeout_ms: 500
       ]}
    )

    {:ok, supervisor_name: supervisor_name, prefix: prefix}
  end

  test "uses EctoStore backend defaults for heartbeat tracking and intervals", %{
    supervisor_name: supervisor_name
  } do
    config = DurableServer.Supervisor.__get_config__(supervisor_name)

    assert config.heartbeat_tracking_mode == :poll
    assert config.discovery_interval_ms == 3_000
    assert config.heartbeat_interval_ms == 10_000
    assert config.heartbeat_reconcile_interval_ms == 30_000
  end

  test "persists and reloads state with existing: true", %{supervisor_name: supervisor_name} do
    key = "counter-restart"

    {:ok, {pid, _meta}} =
      DurableServer.Supervisor.start_child(
        supervisor_name,
        {CounterServer, key: key, initial_state: %{count: 0}}
      )

    assert 1 = GenServer.call(pid, :increment_and_sync)

    monitor_ref = Process.monitor(pid)
    assert :ok = DurableServer.Supervisor.terminate_child(supervisor_name, pid)
    assert_receive {:DOWN, ^monitor_ref, :process, ^pid, _reason}, 5_000

    assert nil == DurableServer.Supervisor.lookup(supervisor_name, key)

    {:ok, {restarted_pid, _meta}} =
      DurableServer.Supervisor.start_child(
        supervisor_name,
        {CounterServer, key: key, initial_state: %{}},
        existing: true
      )

    assert 1 == GenServer.call(restarted_pid, :get_count)
  end

  test "concurrent starts for the same key resolve to a single owner", %{
    supervisor_name: supervisor_name
  } do
    key = "counter-concurrent"

    results =
      1..16
      |> Task.async_stream(
        fn _ ->
          DurableServer.Supervisor.start_child(
            supervisor_name,
            {CounterServer, key: key, initial_state: %{count: 0}}
          )
        end,
        max_concurrency: 16,
        ordered: false,
        timeout: :timer.seconds(10)
      )
      |> Enum.map(fn {:ok, result} -> result end)

    successes =
      Enum.filter(results, fn
        {:ok, {pid, _meta}} when is_pid(pid) -> true
        _ -> false
      end)

    assert length(successes) == 1

    assert Enum.all?(results, fn
             {:ok, {pid, _meta}} when is_pid(pid) ->
               true

             {:error, {:already_started, {pid, _meta}}} when is_pid(pid) ->
               true

             {:error, {:already_started, pid}} when is_pid(pid) ->
               true

             _ ->
               false
           end)

    assert match?(
             {pid, _meta} when is_pid(pid),
             DurableServer.Supervisor.lookup(supervisor_name, key)
           )
  end

  test "streams persisted keys through EKV backend", %{
    supervisor_name: supervisor_name,
    prefix: prefix
  } do
    {:ok, _} =
      DurableServer.Supervisor.start_child(
        supervisor_name,
        {CounterServer, key: "a", initial_state: %{count: 1}}
      )

    {:ok, _} =
      DurableServer.Supervisor.start_child(
        supervisor_name,
        {CounterServer, key: "b", initial_state: %{count: 2}}
      )

    %{storage_backend: storage_backend} = DurableServer.Supervisor.__get_config__(supervisor_name)

    listed_keys =
      StorageBackend.list_all_objects_stream(storage_backend, prefix, consistent: false)
      |> Enum.map(& &1.key)

    assert "#{prefix}a" in listed_keys
    assert "#{prefix}b" in listed_keys

    listed_objects =
      StorageBackend.list_all_objects_stream(storage_backend, prefix,
        consistent: false,
        include_objects: true
      )
      |> Enum.filter(&(&1.key in ["#{prefix}a", "#{prefix}b"]))
      |> Enum.map(fn %{key: key, body: %StoredState{} = body} -> {key, body.state["count"]} end)

    assert {"#{prefix}a", 1} in listed_objects
    assert {"#{prefix}b", 2} in listed_objects
  end
end
