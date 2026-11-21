defmodule DpulCollectionsWeb.Dav.Plug do
  @moduledoc """
  Read-only WebDAV (class 1) endpoint over `DpulCollections.Dav.Tree`.

  Mounted in the endpoint (ahead of Plug.Head / Plug.Parsers / the session)
  so HEAD stays HEAD and PROPFIND bodies are left alone. Requests outside
  `@prefix` pass straight through.

  Supports OPTIONS, PROPFIND (Depth 0/1), GET and HEAD. Image files are
  streamed from the IIIF image server; directories render a simple HTML
  index when opened in a browser.
  """
  import Plug.Conn
  alias DpulCollections.Dav.{Cache, Tree}
  require Logger

  @prefix "dav"
  @allow "OPTIONS, GET, HEAD, PROPFIND"

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: [@prefix | segments]} = conn, _opts) do
    # At the endpoint level path_info is still percent-encoded (the Router
    # normally decodes it).
    segments = Enum.map(segments, &URI.decode/1)

    conn
    |> put_resp_header("dav", "1")
    |> put_resp_header("ms-author-via", "DAV")
    |> handle(conn.method, segments)
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp handle(conn, "OPTIONS", _segments) do
    conn
    |> put_resp_header("allow", @allow)
    |> send_resp(200, "")
  end

  defp handle(conn, "PROPFIND", segments) do
    with {:ok, entry} <- Tree.resolve(segments) do
      entries =
        case get_req_header(conn, "depth") do
          ["0"] -> [entry]
          # Depth 1, and "infinity" treated as 1 rather than walking 90k items.
          _ -> [entry | Tree.children(entry)]
        end

      conn
      |> put_resp_content_type("application/xml", "utf-8")
      |> send_resp(207, multistatus(entries))
    else
      :not_found -> send_resp(conn, 404, "")
    end
  end

  defp handle(conn, method, segments) when method in ["GET", "HEAD"] do
    case Tree.resolve(segments) do
      {:ok, %{type: :dir} = entry} -> send_index(conn, entry, segments)
      {:ok, %{kind: :image} = entry} -> send_image(conn, entry)
      {:ok, entry} -> send_text(conn, entry)
      :not_found -> send_resp(conn, 404, "Not found")
    end
  end

  defp handle(conn, _method, _segments) do
    conn
    |> put_resp_header("allow", @allow)
    |> send_resp(405, "This file system is read-only.")
  end

  ## GET / HEAD

  defp send_text(conn, entry) do
    conn
    |> put_resp_content_type(entry.content_type, nil)
    |> put_common_headers(entry)
    |> send_resp(200, entry.content)
  end

  defp send_image(%{method: "HEAD"} = conn, entry) do
    conn = conn |> put_resp_content_type("image/jpeg", nil) |> put_common_headers(entry)

    case Cache.size(Tree.download_url(entry)) do
      nil -> send_resp(conn, 200, "")
      size -> conn |> put_resp_header("content-length", "#{size}") |> send_resp(200, "")
    end
  end

  # Stream straight from the IIIF server so the first byte arrives quickly,
  # then remember the total size for future PROPFINDs.
  defp send_image(conn, entry) do
    url = Tree.download_url(entry)

    resp =
      [url: url, into: :self, retry: false, receive_timeout: 60_000]
      |> Keyword.merge(Application.get_env(:dpul_collections, :dav_image_req_options, []))
      |> Req.get!()

    if resp.status != 200 do
      Req.cancel_async_response(resp)
      send_resp(conn, 502, "Image server returned #{resp.status}")
    else
      conn =
        conn
        |> put_resp_content_type("image/jpeg", nil)
        |> put_common_headers(entry)
        |> send_chunked(200)

      result =
        Enum.reduce_while(resp.body, {conn, 0}, fn data, {conn, bytes} ->
          case chunk(conn, data) do
            {:ok, conn} -> {:cont, {conn, bytes + byte_size(data)}}
            # coveralls-ignore-next-line
            {:error, _reason} -> {:halt, {:closed, conn}}
          end
        end)

      case result do
        # Client hung up mid-download; stop pulling from the image server.
        # coveralls-ignore-start
        {:closed, conn} ->
          Req.cancel_async_response(resp)
          conn

        # coveralls-ignore-stop

        {conn, bytes} ->
          Cache.put_size(url, bytes)
          conn
      end
    end
  end

  defp put_common_headers(conn, entry) do
    conn
    |> put_resp_header("last-modified", http_date(entry.modified))
    |> put_resp_header("etag", etag(entry))
    |> put_resp_header("cache-control", "public, max-age=3600")
  end

  ## PROPFIND

  defp multistatus(entries) do
    responses = Enum.map(entries, &prop_response/1)

    [
      ~s(<?xml version="1.0" encoding="utf-8"?>\n<D:multistatus xmlns:D="DAV:">\n),
      responses,
      "</D:multistatus>\n"
    ]
  end

  defp prop_response(entry) do
    modified = http_date(entry.modified)

    props =
      case entry.type do
        :dir ->
          ["<D:resourcetype><D:collection/></D:resourcetype>"]

        :file ->
          size = entry.size || Cache.size(Tree.download_url(entry))

          [
            "<D:resourcetype/>",
            "<D:getcontenttype>#{entry.content_type}</D:getcontenttype>",
            "<D:getetag>#{etag(entry)}</D:getetag>",
            if(size, do: "<D:getcontentlength>#{size}</D:getcontentlength>", else: [])
          ]
      end

    [
      "<D:response><D:href>",
      href(entry),
      "</D:href><D:propstat><D:prop>",
      "<D:displayname>",
      xml_escape(entry.name),
      "</D:displayname>",
      "<D:getlastmodified>#{modified}</D:getlastmodified>",
      "<D:creationdate>#{iso_date(entry.modified)}</D:creationdate>",
      props,
      "</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>\n"
    ]
  end

  defp href(entry) do
    path =
      Enum.map_join([@prefix | entry.path], "/", fn segment ->
        URI.encode(segment, &URI.char_unreserved?/1)
      end)

    "/" <> path <> if(entry.type == :dir, do: "/", else: "")
  end

  defp etag(entry) do
    key = {entry.path, entry.modified, entry.size}
    ~s("#{:erlang.phash2(key) |> Integer.to_string(16)}")
  end

  # The collection has no real timestamps for synthetic folders; use a stable
  # date so clients don't think things change on every listing.
  @epoch ~U[2024-01-01 00:00:00Z]

  defp parse_date(nil), do: @epoch

  # Solr date fields are always ISO 8601.
  defp parse_date(value) when is_binary(value) do
    {:ok, dt, _offset} = DateTime.from_iso8601(value)
    dt
  end

  defp http_date(value),
    do: value |> parse_date() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

  defp iso_date(value), do: value |> parse_date() |> DateTime.to_iso8601()

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  ## Browser index

  defp send_index(conn, entry, segments) do
    if String.ends_with?(conn.request_path, "/") or segments == [] do
      html = index_html(entry, Tree.children(entry))
      conn |> put_resp_content_type("text/html", "utf-8") |> send_resp(200, html)
    else
      # Relative links only work when directories end in a slash.
      conn
      |> put_resp_header("location", href(entry))
      |> send_resp(301, "")
    end
  end

  defp index_html(entry, children) do
    crumbs =
      [{"Digital Collections", "/#{@prefix}/"}] ++
        (entry.path
         |> Enum.with_index(1)
         |> Enum.map(fn {name, idx} ->
           {name, href(%Tree.Entry{type: :dir, path: Enum.take(entry.path, idx)})}
         end))

    {images, others} = Enum.split_with(children, &(&1.kind == :image))

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>#{xml_escape(List.last(entry.path) || "Digital Collections")} · WebDAV</title>
    <style>
      :root { --bg:#f4f2f0; --ink:#121212; --accent:#a0562c; --rule:#d8d2cc; --muted:#6b645e; }
      * { box-sizing: border-box; }
      body { margin:0; background:var(--bg); color:var(--ink); font:15px/1.5 ui-sans-serif, system-ui, sans-serif; }
      main { max-width: 960px; margin: 0 auto; padding: 32px 16px 64px; }
      .eyebrow { font-size:.65rem; letter-spacing:.14em; text-transform:uppercase; font-weight:600; color:var(--muted); }
      nav { margin: 6px 0 24px; font-size:.9rem; overflow-wrap:anywhere; }
      nav a { color: var(--accent); text-decoration:none; }
      nav span { color: var(--muted); margin: 0 6px; }
      h1 { font-size: 1.6rem; margin: 0 0 4px; font-weight: 600; overflow-wrap:anywhere; }
      .hint { color: var(--muted); font-size: .85rem; margin: 0 0 24px; border-left: 3px solid #8a9a7b; padding-left: 10px; }
      code { background:#fff; padding:1px 5px; border:1px solid var(--rule); }
      ul { list-style:none; padding:0; margin:0; border-top:1px solid var(--rule); }
      li a { display:flex; gap:12px; padding:9px 4px; border-bottom:1px solid var(--rule); color:var(--ink); text-decoration:none; }
      li a:hover { background:#fff; }
      .kind { width: 1.25rem; flex:none; color: var(--accent); }
      .grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(150px, 1fr)); gap:12px; margin: 0 0 24px; }
      .grid a { display:block; background:#fff; padding:8px; color:var(--ink); text-decoration:none; font-size:.8rem; border:1px solid var(--rule); }
      .grid img { width:100%; height:150px; object-fit:contain; background:#eae6e2; display:block; margin-bottom:6px; }
    </style>
    </head>
    <body><main>
    <div class="eyebrow">Princeton University Library · Read-only WebDAV</div>
    <nav>#{crumbs |> Enum.map(fn {name, link} -> ~s(<a href="#{link}">#{xml_escape(name)}</a>) end) |> Enum.join("<span>/</span>")}</nav>
    <h1 dir="auto">#{xml_escape(List.last(entry.path) || "Digital Collections")}</h1>
    <p class="hint">Mount <code>#{xml_escape(DpulCollectionsWeb.Endpoint.url())}/#{@prefix}/</code> as a network drive to copy whole folders.</p>
    #{image_grid(images)}
    <ul>
    #{Enum.map_join(others, "\n", &index_row/1)}
    </ul>
    </main></body></html>
    """
  end

  defp image_grid([]), do: ""

  defp image_grid(images) do
    cells =
      Enum.map_join(images, "\n", fn image ->
        ~s(<a href="#{href(image)}"><img loading="lazy" alt="" src="#{Tree.thumbnail_url(image)}">#{xml_escape(image.name)}</a>)
      end)

    ~s(<div class="grid">#{cells}</div>)
  end

  defp index_row(entry) do
    icon = if entry.type == :dir, do: "▸", else: "·"

    ~s(<li><a href="#{href(entry)}"><span class="kind">#{icon}</span><span dir="auto">#{xml_escape(entry.name)}</span></a></li>)
  end
end
