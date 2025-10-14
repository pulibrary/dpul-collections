defmodule DpulCollections.UserSetsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `DpulCollections.UserSets` context.
  """

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
end
