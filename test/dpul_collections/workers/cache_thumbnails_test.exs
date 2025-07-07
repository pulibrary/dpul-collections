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

        # Setup ETS table to store image paths.
        # Acts as storage for paths that are requested in different
        # processes so they can be tested after the job has run.
        :ets.new(:cached_paths, [:named_table, :public])

        Req.Test.stub(DpulCollections.Workers.CacheThumbnails, fn conn ->
          # Insert reqested path into ETS table
          %{request_path: request_path} = conn
          :ets.insert(:cached_paths, {request_path, request_path})

          conn
          |> Plug.Conn.put_resp_content_type("image/jpeg")
          |> Plug.Conn.send_resp(200, "image")
        end)

        {:ok, %Oban.Job{state: state}} =
          Oban.insert(DpulCollections.Workers.CacheThumbnails.new(%{solr_document: doc}))

        assert state == "completed"

        cached_paths = :ets.tab2list(:cached_paths) |> Enum.map(fn t -> elem(t, 0) end)

        # Primary thumbnail
        assert cached_paths |> Enum.member?("/iiif/2/image2/full/!453,800/0/default.jpg")
        # Item page thumbnails
        assert cached_paths |> Enum.member?("/iiif/2/image1/full/350,465/0/default.jpg")
        # Browse and search results thumbnails
        assert cached_paths |> Enum.member?("/iiif/2/image2/square/350,350/0/default.jpg")
        # Small browse thumbnails
        assert cached_paths |> Enum.member?("/iiif/2/image7/square/100,100/0/default.jpg")
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
