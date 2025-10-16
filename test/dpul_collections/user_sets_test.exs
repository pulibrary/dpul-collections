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

    test "list_user_sets_for_addition/2 returns all user sets, how many SetItems it has, and if the given ItemID is in there" do
      scope = user_scope_fixture()
      # Make another user, make sure their sets don't get returned.
      _other_scope = user_scope_fixture()
      set = set_fixture(scope, %{title: "The First Set"})
      other_set = set_fixture(scope, %{title: "The Second Set"})
      set_item = set_item_fixture(%{solr_id: "123"}, scope, set)
      _set_item_2 = set_item_fixture(%{}, scope, set)

      sets = UserSets.list_user_sets_for_addition(scope, set_item.solr_id)
      assert length(sets) == 2

      [first_set, second_set] = sets
      assert first_set.set_item_count == 2
      assert second_set.set_item_count == 0
      assert first_set.has_solr_id == true
      assert second_set.has_solr_id == false
      assert first_set.title == "The First Set"
      assert second_set.title == other_set.title
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

    test "create_set/2 can create a set with an item" do
      valid_attrs = %{"title" => "Test Set", "set_items" => [%{"solr_id" => "test"}]}
      scope = user_scope_fixture()

      assert {:ok, %Set{}} = UserSets.create_set(scope, valid_attrs)
      [first_set] = UserSets.list_user_sets_for_addition(scope)
      assert first_set.set_item_count == 1
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

  describe "user_set_items" do
    alias DpulCollections.UserSets.SetItem

    import DpulCollections.UserSetsFixtures
    import DpulCollections.AccountsFixtures, only: [user_scope_fixture: 0]

    @invalid_attrs %{solr_id: nil}

    test "list_user_set_items/0 returns all user_set_items" do
      set_item = set_item_fixture()
      assert UserSets.list_user_set_items() == [set_item]
    end

    test "get_set_item!/1 returns the set_item with given id" do
      set_item = set_item_fixture()
      assert UserSets.get_set_item!(set_item.id) == set_item
    end

    test "create_set_item/1 with valid data creates a set_item" do
      scope = user_scope_fixture()
      set = set_fixture(scope)
      valid_attrs = %{solr_id: "some solr_id", set_id: set.id}

      assert {:ok, %SetItem{} = set_item} = UserSets.create_set_item(valid_attrs)
      assert set_item.solr_id == "some solr_id"
    end

    test "create_set_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UserSets.create_set_item(@invalid_attrs)
    end

    test "update_set_item/2 with valid data updates the set_item" do
      set_item = set_item_fixture()
      update_attrs = %{solr_id: "some updated solr_id"}

      assert {:ok, %SetItem{} = set_item} = UserSets.update_set_item(set_item, update_attrs)
      assert set_item.solr_id == "some updated solr_id"
    end

    test "update_set_item/2 with invalid data returns error changeset" do
      set_item = set_item_fixture()
      assert {:error, %Ecto.Changeset{}} = UserSets.update_set_item(set_item, @invalid_attrs)
      assert set_item == UserSets.get_set_item!(set_item.id)
    end

    test "delete_set_item/1 deletes the set_item" do
      set_item = set_item_fixture()
      assert {:ok, %SetItem{}} = UserSets.delete_set_item(set_item)
      assert_raise Ecto.NoResultsError, fn -> UserSets.get_set_item!(set_item.id) end
    end

    test "change_set_item/1 returns a set_item changeset" do
      set_item = set_item_fixture()
      assert %Ecto.Changeset{} = UserSets.change_set_item(set_item)
    end
  end
end
