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
          "format" => ""
        }
      }

      assert Helpers.clean_params(test_map) == %{
               "stay" => "1",
               "filter" => %{"year" => %{"from" => "1900"}}
             }
    end
  end

  describe "search_path/1" do
    test "encodes square brackets in query params" do
      assert Helpers.search_path(%{filter: %{"format" => ["Pamphlets"]}}) ==
               "/search?filter%5Bformat%5D%5B%5D=Pamphlets"
    end

    test "encodes brackets in range params" do
      assert Helpers.search_path(%{filter: %{"year" => %{"from" => "1900", "to" => "2000"}}}) ==
               "/search?filter%5Byear%5D%5Bfrom%5D=1900&filter%5Byear%5D%5Bto%5D=2000"
    end

    test "query params without brackets are unchanged" do
      assert Helpers.search_path(%{q: "posters", sort_by: "date_asc"}) ==
               "/search?q=posters&sort_by=date_asc"
    end
  end
end
