defmodule DpulCollections.Workers.CacheThumbnailsTest do
  use DpulCollections.DataCase

  describe ".perform/" do
    test "item thumbnails are cached when item does not have primary thumbnail url" do
      Oban.Testing.with_testing_mode(:inline, fn ->
        doc = SolrTestSupport.mock_solr_documents(1) |> hd

        Req.Test.stub(DpulCollections.Workers.CacheThumbnails, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "image")
        end)

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheThumbnails.new(%{solr_document: doc}))

        assert state == "completed"
      end)
    end

    test "item thumbnails are cached when item does have primary thumbnail url" do
      Oban.Testing.with_testing_mode(:inline, fn ->
        doc = SolrTestSupport.mock_solr_documents(2) |> Enum.at(1)

        Req.Test.stub(DpulCollections.Workers.CacheThumbnails, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "image")
        end)

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheThumbnails.new(%{solr_document: doc}))

        assert state == "completed"
      end)
    end

    test "solr documents marked for deletion do not raise an error" do
      Oban.Testing.with_testing_mode(:inline, fn ->
        doc = %{id: 1, deleted: true}

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheThumbnails.new(%{solr_document: doc}))

        assert state == "completed"
      end)
    end
  end
end
