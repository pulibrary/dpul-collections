defmodule DpulCollections.UserSetsTest do
  use DpulCollections.DataCase

  alias DpulCollections.UserSets

  describe "user_sets" do
    alias DpulCollections.UserSets.Set

    import DpulCollections.AccountsFixtures, only: [user_scope_fixture: 0]
    import DpulCollections.UserSetsFixtures

    @invalid_attrs %{title: ""}

    test "list_user_sets/1 returns all scoped user_sets" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      set = set_fixture(scope)
      other_set = set_fixture(other_scope)
      assert UserSets.list_user_sets(scope) == [set]
      assert UserSets.list_user_sets(other_scope) == [other_set]
    end

    test "get_set!/2 returns the set with given id" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      other_scope = user_scope_fixture()
      assert UserSets.get_set!(scope, set.id) == set
      assert_raise Ecto.NoResultsError, fn -> UserSets.get_set!(other_scope, set.id) end
    end

    test "create_set/2 with valid data creates a set" do
      valid_attrs = %{title: "Test Title"}
      scope = user_scope_fixture()

      assert {:ok, %Set{} = set} = UserSets.create_set(scope, valid_attrs)
      assert set.user_id == scope.user.id
    end

    test "create_set/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = UserSets.create_set(scope, @invalid_attrs)
    end

    test "update_set/3 with valid data updates the set" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      update_attrs = %{}

      assert {:ok, %Set{} = ^set} = UserSets.update_set(scope, set, update_attrs)
    end

    test "update_set/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      set = set_fixture(scope)

      assert_raise MatchError, fn ->
        UserSets.update_set(other_scope, set, %{})
      end
    end

    test "update_set/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = UserSets.update_set(scope, set, @invalid_attrs)
      assert set == UserSets.get_set!(scope, set.id)
    end

    test "delete_set/2 deletes the set" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      assert {:ok, %Set{}} = UserSets.delete_set(scope, set)
      assert_raise Ecto.NoResultsError, fn -> UserSets.get_set!(scope, set.id) end
    end

    test "delete_set/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      set = set_fixture(scope)
      assert_raise MatchError, fn -> UserSets.delete_set(other_scope, set) end
    end

    test "change_set/2 returns a set changeset" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      assert %Ecto.Changeset{} = UserSets.change_set(scope, set)
    end
  end
end
