defmodule DpulCollections.Workers.CacheHeroImagesTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  import SolrTestSupport

  setup do
    Solr.delete_all(active_collection())
    on_exit(fn -> Solr.delete_all(active_collection()) end)
  end

  describe ".perform/" do
    test "item hero images are cached" do
      Oban.Testing.with_testing_mode(:inline, fn ->
        doc = SolrTestSupport.mock_solr_documents(1) |> hd
        Solr.add([doc], active_collection())
        Solr.commit(active_collection())

        Req.Test.stub(DpulCollections.Workers.CacheHeroImages, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "image")
        end)

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheHeroImages.new(%{}))

        assert state == "completed"
      end)
    end
  end
end
