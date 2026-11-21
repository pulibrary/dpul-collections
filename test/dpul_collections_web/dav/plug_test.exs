defmodule DpulCollectionsWeb.Dav.PlugTest do
  use DpulCollectionsWeb.ConnCase
  alias DpulCollections.Solr

  @item_id "e241fb30-72c8-4a1e-8e52-0e57b882e36e"
  @item_dir "/dav/Collections/Greek%20Ephemera/Posters/" <>
              "4%CE%BF%20%CE%A6%CE%B5%CF%83%CF%84%CE%B9%CE%B2%CE%AC%CE%BB%20%5Be241fb30%5D/"

  setup do
    Solr.add([
      %{
        id: "0eeebbad-c310-43a9-b6b1-d635e3e097f2",
        resource_type_s: "collection",
        title_txtm: ["Greek Ephemera"],
        authoritative_slug_s: "greek",
        tagline_txtm: ["Posters and pamphlets"],
        summary_txtm: ["<p>Printed <em>ephemera</em> from Greece.</p>"]
      },
      %{
        id: @item_id,
        title_txtm: ["4ο Φεστιβάλ"],
        format_txt_sort: ["Posters"],
        collection_titles_ss: ["Greek Ephemera"],
        content_warning_s: "Graphic imagery",
        image_service_urls_ss: [
          "https://iiif.example.com/iiif/2/one",
          "https://iiif.example.com/iiif/2/two"
        ]
      },
      %{
        id: "11111111-0000-0000-0000-000000000000",
        title_txtm: ["Untyped thing"],
        collection_titles_ss: ["Greek Ephemera"]
      }
    ])

    Solr.soft_commit(active_collection())
    :ok
  end

  defp propfind(conn, path, depth \\ "1") do
    conn
    |> put_req_header("depth", depth)
    |> dispatch(@endpoint, "PROPFIND", path)
  end

  defp names(conn),
    do:
      Regex.scan(~r/<D:displayname>(.*?)<\/D:displayname>/, conn.resp_body,
        capture: :all_but_first
      )
      |> List.flatten()

  test "OPTIONS advertises a read-only DAV class 1 server", %{conn: conn} do
    conn = dispatch(conn, @endpoint, "OPTIONS", "/dav/")
    assert conn.status == 200
    assert get_resp_header(conn, "dav") == ["1"]
    assert get_resp_header(conn, "allow") == ["OPTIONS, GET, HEAD, PROPFIND"]
  end

  test "PROPFIND walks collection → format → item → files", %{conn: conn} do
    assert propfind(conn, "/dav/") |> names() == ["", "Collections", "README.txt"]

    conn_collections = propfind(conn, "/dav/Collections/")
    assert conn_collections.status == 207
    assert "Greek Ephemera" in names(conn_collections)
    assert conn_collections.resp_body =~ "<D:href>/dav/Collections/Greek%20Ephemera/</D:href>"

    assert propfind(conn, "/dav/Collections/Greek%20Ephemera/") |> names() ==
             ["Greek Ephemera", "About this collection.txt", "Other", "Posters"]

    assert propfind(conn, "/dav/Collections/Greek%20Ephemera/Posters/") |> names() ==
             ["Posters", "4ο Φεστιβάλ [e241fb30]"]

    item = propfind(conn, @item_dir)

    assert names(item) == [
             "4ο Φεστιβάλ [e241fb30]",
             "CONTENT WARNING.txt",
             "001.jpg",
             "002.jpg",
             "metadata.json"
           ]

    assert item.resp_body =~ "<D:getcontenttype>image/jpeg</D:getcontenttype>"
  end

  test "Depth 0 returns only the resource itself", %{conn: conn} do
    assert propfind(conn, "/dav/Collections/", "0") |> names() == ["Collections"]
  end

  test "GET serves generated text files", %{conn: conn} do
    conn = get(conn, @item_dir <> "metadata.json")
    assert conn.status == 200
    assert %{"id" => @item_id, "Format" => "Posters"} = Jason.decode!(conn.resp_body)

    about = get(build_conn(), "/dav/Collections/Greek%20Ephemera/About%20this%20collection.txt")
    assert about.resp_body =~ "Posters and pamphlets"
    assert about.resp_body =~ "Printed ephemera from Greece."
    assert about.resp_body =~ "/collections/greek"
  end

  test "GET on a directory renders a browsable HTML index", %{conn: conn} do
    assert get(conn, "/dav/Collections") |> redirected_to(301) == "/dav/Collections/"

    html = get(build_conn(), @item_dir) |> html_response(200)
    assert html =~ "https://iiif.example.com/iiif/2/one/full/!350,350/0/default.jpg"
  end

  test "unknown paths and client junk files are 404s", %{conn: conn} do
    assert propfind(conn, "/dav/Collections/Nope/").status == 404
    assert propfind(build_conn(), "/dav/Collections/.DS_Store").status == 404
    assert get(build_conn(), @item_dir <> "999.jpg").status == 404
  end

  describe "images" do
    test "GET streams the full-size IIIF image and remembers its size", %{conn: conn} do
      Req.Test.stub(DpulCollectionsWeb.Dav.Plug, fn req ->
        assert req.request_path == "/iiif/2/one/full/!2000,2000/0/default.jpg"
        Plug.Conn.send_resp(req, 200, "jpegbytes")
      end)

      # Size is unknown until first download.
      refute propfind(conn, @item_dir <> "001.jpg", "0").resp_body =~ "getcontentlength"
      head = head(build_conn(), @item_dir <> "001.jpg")
      assert head.status == 200
      assert get_resp_header(head, "content-length") == []

      image = get(build_conn(), @item_dir <> "001.jpg")
      assert image.status == 200
      assert image.resp_body == "jpegbytes"
      assert get_resp_header(image, "content-type") == ["image/jpeg"]

      assert propfind(build_conn(), @item_dir <> "001.jpg", "0").resp_body =~
               "<D:getcontentlength>9</D:getcontentlength>"

      assert head(build_conn(), @item_dir <> "001.jpg") |> get_resp_header("content-length") ==
               ["9"]
    end

    test "GET reports a bad gateway when the image server fails", %{conn: conn} do
      Req.Test.stub(DpulCollectionsWeb.Dav.Plug, &Plug.Conn.send_resp(&1, 500, "nope"))
      assert get(conn, @item_dir <> "002.jpg").status == 502
    end
  end

  describe "larger folders and multi-volume works" do
    setup do
      Solr.add([
        %{
          id: "aaaaaaaa-0000-0000-0000-000000000001",
          title_txtm: ["Alpha pamphlet with a fairly long title indeed"],
          format_txt_sort: ["Pamphlets"],
          collection_titles_ss: ["Greek Ephemera"],
          updated_at_dt: "2025-09-17T18:40:00Z"
        },
        %{
          id: "bbbbbbbb-0000-0000-0000-000000000002",
          title_txtm: ["Beta"],
          format_txt_sort: ["Pamphlets"],
          collection_titles_ss: ["Greek Ephemera"]
        },
        %{
          id: "cccccccc-0000-0000-0000-000000000003",
          title_txtm: ["Gamma set"],
          format_txt_sort: ["Pamphlets"],
          collection_titles_ss: ["Greek Ephemera"],
          multi_part_work_b: true
        },
        %{
          id: "dddddddd-0000-0000-0000-000000000004",
          title_txtm: [""],
          format_txt_sort: ["Pamphlets"],
          collection_titles_ss: ["Greek Ephemera"],
          parent_id_s: "cccccccc-0000-0000-0000-000000000003",
          parent_idx_i: 0
        }
      ])

      Solr.soft_commit(active_collection())
      Application.put_env(:dpul_collections, :dav_page_size, 2)
      on_exit(fn -> Application.delete_env(:dpul_collections, :dav_page_size) end)
    end

    test "splits big folders into title-range pages and nests volumes", %{conn: conn} do
      pamphlets = "/dav/Collections/Greek%20Ephemera/Pamphlets/"

      # 3 top-level items (the volume lives under its parent) → 2 pages of ≤2.
      assert propfind(conn, pamphlets) |> names() == [
               "Pamphlets",
               "001 Alpha pamphlet with a fa… – Beta",
               "002 Gamma set – Gamma set"
             ]

      page_one =
        pamphlets <> "001%20Alpha%20pamphlet%20with%20a%20fa%E2%80%A6%20%E2%80%93%20Beta/"

      page = propfind(build_conn(), page_one)

      assert names(page) |> tl() == [
               "Alpha pamphlet with a fairly long title indeed [aaaaaaaa]",
               "Beta [bbbbbbbb]"
             ]

      assert page.resp_body =~ "<D:getlastmodified>Wed, 17 Sep 2025 18:40:00 GMT"

      mvw =
        pamphlets <> "002%20Gamma%20set%20%E2%80%93%20Gamma%20set/Gamma%20set%20%5Bcccccccc%5D/"

      assert propfind(build_conn(), mvw) |> names() ==
               ["Gamma set [cccccccc]", "01 Untitled [dddddddd]", "metadata.json"]

      assert propfind(build_conn(), mvw <> "01%20Untitled%20%5Bdddddddd%5D/").status == 207
    end
  end

  test "PROPFIND on a file returns just the file", %{conn: conn} do
    assert propfind(conn, "/dav/README.txt") |> names() == ["README.txt"]
  end

  test "folders without images render a plain list", %{conn: conn} do
    html = get(conn, "/dav/") |> html_response(200)
    assert html =~ ~s(href="/dav/Collections/")
    refute html =~ ~s(class="grid")
  end

  test "Cache.fetch memoizes within the TTL" do
    alias DpulCollections.Dav.Cache
    Application.put_env(:dpul_collections, :dav_cache_ttl_ms, 60_000)
    on_exit(fn -> Application.put_env(:dpul_collections, :dav_cache_ttl_ms, 0) end)
    key = {:test, make_ref()}

    assert Cache.fetch(key, fn -> 1 end) == 1
    assert Cache.fetch(key, fn -> 2 end) == 1
  end

  test "writes are rejected", %{conn: conn} do
    for method <- ["PUT", "DELETE", "MKCOL", "MOVE", "COPY", "PROPPATCH", "LOCK"] do
      assert dispatch(conn, @endpoint, method, "/dav/README.txt").status == 405
    end
  end

  test "sanitize/1 makes names safe on every OS" do
    alias DpulCollections.Dav.Tree
    assert Tree.sanitize("a/b: c?  d.") == "a b c d"
    assert Tree.sanitize("...leading dots") == "leading dots"
    assert Tree.sanitize("   ") == "Untitled"
  end
end
