defmodule DpulCollections.UserSets do
  @moduledoc """
  The UserSets context.
  """

  import Ecto.Query, warn: false
  alias DpulCollections.UserSets.SetItem
  alias DpulCollections.Repo

  alias DpulCollections.UserSets.Set
  alias DpulCollections.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any set changes.

  The broadcasted messages match the pattern:

    * {:created, %Set{}}
    * {:updated, %Set{}}
    * {:deleted, %Set{}}

  """
  def subscribe_user_sets(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(DpulCollections.PubSub, "user:#{key}:user_sets")
  end

  defp broadcast_set(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(DpulCollections.PubSub, "user:#{key}:user_sets", message)
  end

  @doc """
  Returns the list of user_sets.

  ## Examples

      iex> list_user_sets(scope)
      [%Set{}, ...]

  """
  def list_user_sets(%Scope{} = scope) do
    Repo.all_by(Set, user_id: scope.user.id)
  end

  def list_user_sets_for_addition(%Scope{} = scope, solr_id \\ nil) do
    base_query =
      from t in Set,
        where: t.user_id == ^scope.user.id,
        # Join all set items to get the total count
        left_join: s in assoc(t, :set_items),
        group_by: t.id,
        order_by: [desc: t.inserted_at]

    Repo.all(base_query |> assign_has_solr_id(solr_id))
  end

  # If solr_id is nil it's not safe to join, so always return false for
  # has_solr_id. If we try, then Ecto throws an error.
  defp assign_has_solr_id(base_query, nil) do
    from [t, s] in base_query,
      select_merge: %{
        set_item_count: count(s.id),
        has_solr_id: false
      }
  end

  defp assign_has_solr_id(base_query, solr_id) do
    from [t, s] in base_query,
      left_join: matching_item in DpulCollections.UserSets.SetItem,
      on: matching_item.set_id == t.id and matching_item.solr_id == ^solr_id,
      select_merge: %{
        set_item_count: count(s.id),
        has_solr_id: count(matching_item.id) > 0
      }
  end

  @doc """
  Gets a single set.

  Raises `Ecto.NoResultsError` if the Set does not exist.

  ## Examples

      iex> get_set!(scope, 123)
      %Set{}

      iex> get_set!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_set!(%Scope{} = scope, id) do
    Repo.get_by!(Set, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a set.

  ## Examples

      iex> create_set(scope, %{field: value})
      {:ok, %Set{}}

      iex> create_set(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_set(%Scope{} = scope, attrs) do
    with {:ok, set = %Set{}} <-
           %Set{}
           |> Set.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_set(scope, {:created, set})
      {:ok, set}
    end
  end

  @doc """
  Updates a set.

  ## Examples

      iex> update_set(scope, set, %{field: new_value})
      {:ok, %Set{}}

      iex> update_set(scope, set, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_set(%Scope{} = scope, %Set{} = set, attrs) do
    true = set.user_id == scope.user.id

    with {:ok, set = %Set{}} <-
           set
           |> Set.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_set(scope, {:updated, set})
      {:ok, set}
    end
  end

  @doc """
  Deletes a set.

  ## Examples

      iex> delete_set(scope, set)
      {:ok, %Set{}}

      iex> delete_set(scope, set)
      {:error, %Ecto.Changeset{}}

  """
  def delete_set(%Scope{} = scope, %Set{} = set) do
    true = set.user_id == scope.user.id

    with {:ok, set = %Set{}} <-
           Repo.delete(set) do
      broadcast_set(scope, {:deleted, set})
      {:ok, set}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking set changes.

  ## Examples

      iex> change_set(scope, set)
      %Ecto.Changeset{data: %Set{}}

  """
  def change_set(%Scope{} = scope, %Set{} = set, attrs \\ %{}) do
    true = set.user_id == scope.user.id

    Set.changeset(set, attrs, scope)
  end

  alias DpulCollections.UserSets.SetItem

  @doc """
  Returns the list of user_set_items.

  ## Examples

      iex> list_user_set_items()
      [%SetItem{}, ...]

  """
  def list_user_set_items do
    Repo.all(SetItem)
  end

  @doc """
  Gets a single set_item.

  Raises `Ecto.NoResultsError` if the Set item does not exist.

  ## Examples

      iex> get_set_item!(123)
      %SetItem{}

      iex> get_set_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_set_item!(id), do: Repo.get!(SetItem, id)

  @doc """
  Creates a set_item.

  ## Examples

      iex> create_set_item(%{field: value})
      {:ok, %SetItem{}}

      iex> create_set_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_set_item(attrs) do
    %SetItem{}
    |> SetItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a set_item.

  ## Examples

      iex> update_set_item(set_item, %{field: new_value})
      {:ok, %SetItem{}}

      iex> update_set_item(set_item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_set_item(%SetItem{} = set_item, attrs) do
    set_item
    |> SetItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a set_item.

  ## Examples

      iex> delete_set_item(set_item)
      {:ok, %SetItem{}}

      iex> delete_set_item(set_item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_set_item(%SetItem{} = set_item) do
    Repo.delete(set_item)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking set_item changes.

  ## Examples

      iex> change_set_item(set_item)
      %Ecto.Changeset{data: %SetItem{}}

  """
  def change_set_item(%SetItem{} = set_item, attrs \\ %{}) do
    SetItem.changeset(set_item, attrs)
  end
end
