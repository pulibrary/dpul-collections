defmodule DpulCollectionsWeb.HelpersTest do
  use DpulCollectionsWeb.ConnCase
  alias DpulCollectionsWeb.Live.Helpers

  describe "clean_params/2" do
    test "removes keys with empty values, nil values, or keys to be stripped" do
      test_map = %{
        "stay" => "1",
        "remove" => "",
        "remove_2" => nil,
        "remove_explicit" => "bla"
      }

      assert Helpers.clean_params(test_map, ["remove_explicit"]) == %{"stay" => "1"}
    end

    test "removes nested parameters with empty keys" do
      test_map = %{
        "stay" => "1",
        "remove" => "",
        "remove_2" => nil,
        "filter" => %{
          "year" => %{
            "to" => "",
            "from" => "1900"
          },
          "genre" => ""
        }
      }

      assert Helpers.clean_params(test_map) == %{
               "stay" => "1",
               "filter" => %{"year" => %{"from" => "1900"}}
             }
    end
  end
end
