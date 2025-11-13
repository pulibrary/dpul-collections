defmodule DpulCollectionsWeb.HealthControllerTest do
  use DpulCollectionsWeb.ConnCase

  describe "show/2" do
    test "returns 200 it can be reached", %{conn: conn} do
      expected =
        %{
          results: [
            %{name: "Solr", status: "OK"}
          ]
        }
        |> Jason.encode!()
        |> Jason.decode!()

      Req.Test.stub(DpulCollections.Solr.Client, fn test_conn ->
        test_conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "{}")
      end)

      conn = get(conn, ~p"/health")

      # Assert the response
      assert json_response(conn, 200) == expected
    end

    test "returns 200 even when anything is down", %{conn: conn} do
      expected =
        %{
          results: [
            %{name: "Solr", status: "ERROR"}
          ]
        }
        |> Jason.encode!()
        |> Jason.decode!()

      Req.Test.stub(DpulCollections.Solr.Client, fn test_conn ->
        test_conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, "{}")
      end)

      conn = get(conn, ~p"/health")

      # Assert the response
      assert json_response(conn, 200) == expected
    end
  end
end
