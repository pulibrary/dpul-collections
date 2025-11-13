defmodule DpulCollectionsWeb.HealthControllerTest do
  use DpulCollectionsWeb.ConnCase

  describe "show/2" do
    test "returns 200 when everything is up", %{conn: conn} do
      expected =
        %{
          results: [
            %{name: "Solr", status: "OK"},
            %{name: "Database", status: "OK"}
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

    test "returns 503 when anything is down", %{conn: conn} do
      expected =
        %{
          results: [
            %{name: "Solr", status: "ERROR"},
            %{name: "Database", status: "OK"}
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
      assert json_response(conn, 503) == expected
    end
  end
end
