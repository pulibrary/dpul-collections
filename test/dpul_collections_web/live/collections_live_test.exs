defmodule DpulCollectionsWeb.CollectionsLiveTest do
  use DpulCollectionsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DpulCollections.Solr
  @endpoint DpulCollectionsWeb.Endpoint

  setup do
    Solr.add(SolrTestSupport.mock_solr_documents())

    Solr.add(
      [
        %{
          id: "similar-to-1-is-a-project",
          title_txtm: "Test Project",
          tagline_txtm: "This is a tagline.",
          summary_txtm: ["This is a test description"],
          authoritative_slug_s: "project",
          resource_type_s: "collection",
          banner_image_s: "https://example.com/iiif/2/image2/full/!453,600/0/default.jpg"
        }
      ],
      active_collection()
    )

    Solr.soft_commit(active_collection())
    :ok
  end

  test "/collections/{:slug} 404s with a bad slug", %{conn: conn} do
    assert_error_sent 404, fn ->
      get(conn, "/collections/not-a-real-slug")
    end
  end

  describe "og:metadata" do
    test "displays metadata fields in the header", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/collections/project")

      {:ok, document} = Floki.parse_document(html)

      assert document
             |> Floki.find(~s{meta[property="og:title"][content="Test Project"]})
             |> Enum.any?()

      assert document
             |> Floki.find(
               ~s{meta[property="og:image"][content="https://example.com/iiif/2/image2/full/!453,600/0/default.jpg"]}
             )
             |> Enum.any?()

      assert document
             |> Floki.find(
               ~s{meta[property="og:description"][content="This is a test description"]}
             )
             |> Enum.any?()

      assert document
             |> Floki.find(~s{meta[property="description"][content="This is a test description"]})
             |> Enum.any?()

      assert document
             |> Floki.find(~s{meta[property="og:url"][content="/collections/project"]})
             |> Enum.any?()
    end
  end
end
