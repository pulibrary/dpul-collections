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
        |> JSON.encode!()
        |> JSON.decode!()

      collection = DpulCollections.Solr.Index.read_index().collection

      Req.Test.stub(DpulCollections.Solr.Client, fn test_conn ->
        assert test_conn.request_path == "/solr/#{collection}/admin/ping"

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
        |> JSON.encode!()
        |> JSON.decode!()

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
