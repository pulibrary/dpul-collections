defmodule DpulCollections.Workers.CacheMosaicImagesTest do
  use DpulCollections.DataCase
  alias DpulCollections.Solr
  import SolrTestSupport

  describe ".perform/" do
    test "mosaic images are cached" do
      Oban.Testing.with_testing_mode(:inline, fn ->
        doc = SolrTestSupport.mock_solr_documents(1) |> hd
        Solr.add([doc], active_collection())
        Solr.soft_commit(active_collection())

        Req.Test.stub(DpulCollections.Workers.CacheMosaicImages, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "image")
        end)

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheMosaicImages.new(%{}))

        assert state == "completed"
      end)
    end
  end

  describe ".timeout" do
    test "timeout is set to 10 minutes (600000 milliseconds)" do
      assert DpulCollections.Workers.CacheMosaicImages.timeout("") == 600_000
    end
  end
end
