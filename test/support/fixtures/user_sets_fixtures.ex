defmodule DpulCollections.UserSetsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DpulCollections.UserSets` context.
  """
  alias DpulCollections.AccountsFixtures

  @doc """
  Generate a set.
  """
  def set_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "Test Set",
        description: "Test Description"
      })

    {:ok, set} = DpulCollections.UserSets.create_set(scope, attrs)
    set
  end

  @doc """
  Generate a set_item.
  """
  def set_item_fixture(attrs \\ %{}, scope \\ AccountsFixtures.user_scope_fixture(), set \\ nil) do
    set = set || set_fixture(scope)

    {:ok, set_item} =
      attrs
      |> Enum.into(%{
        solr_id: "some solr_id",
        set_id: set.id
      })
      |> DpulCollections.UserSets.create_set_item()

    set_item
  end
end
