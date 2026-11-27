defmodule DpulCollectionsWeb.Georeferencer.ControllerTest do
  use DpulCollectionsWeb.ConnCase
  import DpulCollections.AccountsFixtures
  alias DpulCollections.Repo
  alias DpulCollections.Georef.Collab
  alias DpulCollections.Georef.Collab.{Atlas, Job}

  @id "00000000-0000-0000-0000-0000000000dd"
  @mask [[0, 0], [1000, 0], [1000, 800], [0, 800]]
  @t %{"a" => 0.04, "b" => 0.0, "tx" => 1.0, "ty" => 2.0}

  setup do
    # a piece of Palmyra NJ (test/support/georef/fixtures)
    atlas =
      Repo.insert!(%Atlas{
        id: @id,
        manifest: "https://figgy.example/manifest",
        label: "Insurance maps of Palmyra",
        bbox: [-75.034, 40.0, -75.024, 40.007],
        canvases:
          for i <- 1..2 do
            %{
              "id" => "c#{i}",
              "label" => "Sheet #{i}",
              "service" => "https://iiif-cloud.princeton.edu/iiif/2/s#{i}",
              "width" => 1000,
              "height" => 800
            }
          end
      })

    Repo.insert!(%Job{
      atlas_id: atlas.id,
      canvas_index: 0,
      status: "done",
      result: %{
        "parts" => [
          %{"part" => 1, "status" => "ok", "mask" => @mask, "transform" => @t, "contrast" => 0.3}
        ]
      }
    })

    Repo.insert!(%Job{atlas_id: atlas.id, canvas_index: 1})
    %{atlas: atlas}
  end

  describe "input" do
    test "everything the browser needs to fit a sheet", %{conn: conn} do
      body = conn |> get(~p"/georeferencer/input/#{@id}/1") |> json_response(200)
      assert body["canvas"]["service"] == "https://iiif-cloud.princeton.edu/iiif/2/s2"
      assert body["osm"] =~ ~r{\A/georeferencer/atlas/#{@id}/osm\.json\?v=\d+\z}
      assert [%{"transform" => t}] = body["neighbours"]
      assert t == @t
      assert body["projection"]["lon0"]
    end

    test "unknown atlases and sheets aren't found", %{conn: conn} do
      assert conn |> get(~p"/georeferencer/input/nope/0") |> response(404) == "not found"
      assert conn |> get(~p"/georeferencer/input/#{@id}/2") |> response(404)
      assert conn |> get(~p"/georeferencer/input/#{@id}/-1") |> response(404)
      assert conn |> get(~p"/georeferencer/input/#{@id}/1x") |> response(404)
    end
  end

  describe "osm" do
    test "the town's streets, cached privately", %{conn: conn} do
      conn = get(conn, ~p"/georeferencer/atlas/#{@id}/osm.json")
      assert %{"groups" => %{"market" => _}, "lines" => [_ | _]} = json_response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["private, max-age=3600"]
    end

    test "an unknown atlas isn't found", %{conn: conn} do
      assert conn |> get(~p"/georeferencer/atlas/nope/osm.json") |> response(404)
    end
  end

  describe "image" do
    test "a same-origin copy of a sheet image region", %{conn: conn} do
      Req.Test.stub(DpulCollections.Georef, fn conn ->
        assert conn.request_path == "/iiif/2/s1/0,0,100,200/!1536,1536/0/default.jpg"
        Plug.Conn.send_resp(conn, 200, "jpeg bytes")
      end)

      conn =
        get(conn, ~p"/georeferencer/image", %{
          "service" => "https://iiif-cloud.princeton.edu/iiif/2/s1",
          "region" => "0,0,100,200",
          "size" => "!1536,1536"
        })

      assert response(conn, 200) == "jpeg bytes"
      assert response_content_type(conn, :jpg) =~ "image/jpeg"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    end

    test "the whole sheet at the default size", %{conn: conn} do
      Req.Test.stub(DpulCollections.Georef, fn conn ->
        assert conn.request_path == "/iiif/2/s2/full/3000,/0/default.jpg"
        Plug.Conn.send_resp(conn, 200, "whole")
      end)

      conn =
        get(conn, ~p"/georeferencer/image", %{
          "service" => "https://iiif-cloud.princeton.edu/iiif/2/s2"
        })

      assert response(conn, 200) == "whole"
    end

    test "only Princeton's images, at the sizes the pipeline uses", %{conn: conn} do
      for params <- [
            %{"service" => "https://evil.example/iiif/2/s1"},
            %{"service" => "https://iiif-cloud.princeton.edu/iiif/2/s1", "size" => "max"},
            %{"service" => "https://iiif-cloud.princeton.edu/iiif/2/s1", "region" => "../x"}
          ] do
        assert conn |> get(~p"/georeferencer/image", params) |> response(400) ==
                 "unsupported image request"
      end
    end
  end

  describe "ocr_file" do
    test "the OCR models from the cache", %{conn: conn} do
      dir = Collab.ocr_model_dir()
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "det.onnx"), "onnx")
      File.write!(Path.join(dir, "keys.json"), ~s(["a"]))

      conn1 = get(conn, ~p"/georeferencer/ocr/det.onnx")
      assert response(conn1, 200) == "onnx"
      assert get_resp_header(conn1, "content-type") == ["application/octet-stream"]
      assert get_resp_header(conn1, "cache-control") == ["public, max-age=604800"]

      conn2 = get(conn, ~p"/georeferencer/ocr/keys.json")
      assert response(conn2, 200) == ~s(["a"])
      assert get_resp_header(conn2, "content-type") == ["application/json"]
    end

    test "onnxruntime-web and leaflet from node_modules", %{conn: conn} do
      for {file, type} <- [
            {"ort-wasm-simd-threaded.jsep.mjs", "text/javascript"},
            {"ort-wasm-simd-threaded.jsep.wasm", "application/wasm"},
            {"leaflet.css", "text/css"}
          ] do
        conn = get(conn, ~p"/georeferencer/ocr/#{file}")
        assert conn.status == 200
        assert get_resp_header(conn, "content-type") == [type]
      end
    end

    test "nothing else, and no model that isn't there", %{conn: conn} do
      assert conn |> get(~p"/georeferencer/ocr/secrets.txt") |> response(404)
      File.rm(Path.join(Collab.ocr_model_dir(), "rec.onnx"))
      assert conn |> get(~p"/georeferencer/ocr/rec.onnx") |> response(404)
    end
  end

  describe "contribution" do
    test "a placement downloads as its IIIF annotation", %{conn: conn} do
      atlas = Collab.atlas(@id)

      {:ok, c} =
        Collab.save(user_fixture(), atlas, 0, %{"verdict" => "placed", "transform" => @t})

      conn = get(conn, ~p"/georeferencer/contributions/#{c.id}")
      body = json_response(conn, 200)
      assert body["type"] == "Annotation"
      assert body["motivation"] == "georeferencing"
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]

      assert get_resp_header(conn, "content-disposition") == [
               ~s(inline; filename="georef-#{c.id}.json")
             ]
    end

    test "\"can't place\" downloads as the verdict", %{conn: conn} do
      {:ok, c} = Collab.save(user_fixture(), Collab.atlas(@id), 1, %{"verdict" => "cannot"})

      assert conn |> get(~p"/georeferencer/contributions/#{c.id}") |> json_response(200) ==
               %{"verdict" => "cannot", "canvas" => "c2", "part" => 1}
    end
  end

  describe "atlas_page" do
    test "the atlas's placed sheets as one AnnotationPage", %{conn: conn} do
      conn = get(conn, ~p"/georeferencer/atlas/#{@id}/georef.json")
      body = json_response(conn, 200)
      assert body["type"] == "AnnotationPage"
      assert [%{"id" => "https://figgy.example/manifest/georef-collab/1"}] = body["items"]
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end

    test "an unknown atlas isn't found", %{conn: conn} do
      assert conn |> get(~p"/georeferencer/atlas/nope/georef.json") |> response(404)
    end
  end
end
