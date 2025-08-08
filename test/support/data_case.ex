defmodule DpulCollections.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use DpulCollections.DataCase, async: true`, although
  this option is not recommended for other databases.
  """
  alias DpulCollections.Solr

  use ExUnit.CaseTemplate

  using do
    quote do
      alias DpulCollections.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import DpulCollections.DataCase
    end
  end

  setup tags do
    DpulCollections.DataCase.setup_sandbox(tags)
    :ok
  end

  setup_all %{async: true} do
    collection_name = "dpulc-#{Ecto.UUID.generate()}"
    Solr.create_collection(collection_name)

    Process.put(
      :dpul_collections_solr,
      DpulCollections.Solr.solr_config()
      |> Map.merge(%{read_collection: "alias-#{collection_name}"})
    )

    Solr.set_alias(collection_name)

    on_exit(fn ->
      Solr.delete_alias("alias-#{collection_name}")
      Solr.delete_collection(collection_name)
    end)

    [collection: collection_name]
  end

  setup %{async: true, collection: collection} do
    Process.put(
      :dpul_collections_solr,
      DpulCollections.Solr.solr_config()
      |> Map.merge(%{read_collection: "alias-#{collection}"})
    )

    Solr.delete_all(collection)
    on_exit(fn -> Solr.delete_all(collection) end)
  end

  setup_all _context do
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(DpulCollections.Repo, shared: not tags[:async])

    pid_2 =
      Ecto.Adapters.SQL.Sandbox.start_owner!(DpulCollections.FiggyRepo, shared: not tags[:async])

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid_2)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
