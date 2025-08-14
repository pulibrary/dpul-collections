defmodule DpulCollections.DpulCollectionsTest do
  use ExUnit.Case

  describe ".is_production()" do
    test "returns false in test" do
      assert DpulCollections.is_production() == false
    end

    test "returns true when configured" do
      initial_env = Application.get_env(:dpul_collections, :environment_name)
      on_exit(fn -> Application.put_env(:dpul_collections, :environment_name, initial_env) end)
      Application.put_env(:dpul_collections, :environment_name, "production")

      assert DpulCollections.is_production() == true
    end
  end
end
