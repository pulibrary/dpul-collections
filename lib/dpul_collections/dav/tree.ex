defmodule DpulCollections.Dav.Tree do
  @moduledoc """
  A read-only virtual file system over the Solr index, used by the WebDAV
  prototype (`DpulCollectionsWeb.Dav.Plug`).

      /
      ├── README.txt
      └── Collections/
          └── <Collection title>/
              ├── About this collection.txt
              └── <Format>/                    (e.g. "Posters", or "Other")
                  ├── <Item title> [1a2b3c4d]/ (directly, when ≤ 500 items)
                  └── 001 Abc… – Def…/         (title-range pages otherwise)
                      └── <Item title> [1a2b3c4d]/
                          ├── 001.jpg …        (full-size IIIF images)
                          ├── metadata.json
                          ├── CONTENT WARNING.txt (when present)
                          └── 01 <Volume title> [5e6f7a8b]/ (multi-volume works)

  Every directory is resolved by listing its parent and matching by name, so
  any path a client sees in a listing round-trips exactly. Listings are cached
  briefly in `DpulCollections.Dav.Cache`.
  """
  alias DpulCollections.Dav.Cache
  alias DpulCollections.Item
  alias DpulCollections.Solr.{Client, Index}

  @item_fl "id,title_ss,updated_at_dt,digitized_at_dt"
  @no_children "-parent_id_s:[* TO *]"

  defmodule Entry do
    @moduledoc false
    defstruct [
      :name,
      :type,
      :kind,
      :path,
      :modified,
      :content,
      :content_type,
      :image_service_url,
      :size
    ]
  end

  def root, do: %Entry{name: "", type: :dir, kind: :root, path: []}

  @doc "Resolve a list of path segments to an entry, or :not_found."
  def resolve(segments) do
    Enum.reduce_while(segments, {:ok, root()}, fn name, {:ok, parent} ->
      with :dir <- parent.type,
           false <- hidden?(name),
           %Entry{} = child <- find_child(parent, name) do
        {:cont, {:ok, child}}
      else
        _ -> {:halt, :not_found}
      end
    end)
  end

  def children(%Entry{type: :dir} = entry) do
    Cache.fetch({:children, entry.path}, fn ->
      entry
      |> list(entry.kind)
      |> Enum.map(&%{&1 | path: entry.path ++ [&1.name]})
    end)
  end

  def children(_), do: []

  @doc """
  URL to download an image entry from. Defaults to a 2000px long edge:
  readable, but ~40× smaller than the multi-megapixel masters. Override with
  `config :dpul_collections, :dav_image_size, "full"` (any IIIF size).
  """
  def download_url(%Entry{image_service_url: url}) when is_binary(url),
    do: "#{url}/full/#{image_size()}/0/default.jpg"

  defp image_size, do: Application.get_env(:dpul_collections, :dav_image_size, "!2000,2000")

  # A size CacheThumbnails pre-warms for every image, so the grid loads fast.
  def thumbnail_url(%Entry{image_service_url: url}) when is_binary(url),
    do: "#{url}/#{DpulCollections.IIIF.primary_search_thumbnail_parameters()}"

  # Clients probe for lots of dotfiles (.DS_Store, ._foo, .hidden, ...).
  defp hidden?(name), do: String.starts_with?(name, ".")

  defp find_child(parent, name) do
    name = normalize(name)
    Enum.find(children(parent), &(normalize(&1.name) == name))
  end

  # macOS may hand back decomposed (NFD) Unicode; compare in NFC.
  defp normalize(name), do: :unicode.characters_to_nfc_binary(name)

  ## Listings, by kind

  defp list(_entry, :root) do
    [
      %Entry{name: "Collections", type: :dir, kind: :collections},
      text_file("README.txt", readme())
    ]
  end

  defp list(_entry, :collections) do
    counts =
      solr(
        q: "*:*",
        rows: 0,
        facet: true,
        "facet.field": "collection_titles_ss",
        "facet.limit": -1
      )
      |> facet_counts("collection_titles_ss")

    solr(
      q: "resource_type_s:collection",
      rows: 1000,
      fl: "id,title_ss,tagline_txtm,summary_txtm,authoritative_slug_s,updated_at_dt"
    )
    |> docs()
    |> Enum.map(fn doc -> {doc, doc["title_ss"] |> List.wrap() |> List.first()} end)
    |> Enum.filter(fn {_doc, title} -> Map.get(counts, title, 0) > 0 end)
    |> Enum.map(fn {doc, title} ->
      %Entry{
        name: sanitize(title),
        type: :dir,
        kind: {:collection, title, doc},
        modified: doc["updated_at_dt"]
      }
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  defp list(_entry, {:collection, title, doc}) do
    collection_fq = ~s(collection_titles_ss:"#{escape(title)}")

    response =
      solr(
        q: "*:*",
        fq: collection_fq,
        fq: @no_children,
        rows: 0,
        facet: true,
        "facet.field": "format_txt_sort",
        "facet.limit": -1,
        "facet.mincount": 1,
        "facet.missing": true
      )

    formats =
      response
      |> facet_counts("format_txt_sort")
      |> Enum.map(fn
        {nil, count} ->
          {"Other", ["-format_txt_sort:[* TO *]"], count}

        {format, count} ->
          {sanitize(format), [~s(format_txt_sort:"#{escape(format)}")], count}
      end)
      |> Enum.sort_by(fn {name, _, _} -> String.downcase(name) end)
      |> Enum.map(fn {name, fqs, count} ->
        %Entry{
          name: name,
          type: :dir,
          kind: {:format, [collection_fq, @no_children | fqs], count},
          modified: doc["updated_at_dt"]
        }
      end)

    [text_file("About this collection.txt", about_collection(doc)) | formats]
  end

  defp list(_entry, {:format, fqs, count}) do
    if count <= page_size(), do: item_entries(fqs, 0, count), else: pages(fqs, count)
  end

  defp list(_entry, {:page, fqs, start, rows}), do: item_entries(fqs, start, rows)

  defp list(_entry, {:item, id}), do: item_children(id)

  # Splits a big folder into title-range subfolders of page_size() items.
  defp pages(fqs, count) do
    titles =
      solr(q: "*:*", fq: fqs, fl: "title_ss", sort: "title_sort asc, id asc", rows: count)
      |> docs()
      |> Enum.map(&title/1)

    titles
    |> Enum.chunk_every(page_size())
    |> Enum.with_index()
    |> Enum.map(fn {chunk, idx} ->
      number = (idx + 1) |> Integer.to_string() |> String.pad_leading(3, "0")
      name = "#{number} #{short(hd(chunk))} – #{short(List.last(chunk))}"

      %Entry{
        name: sanitize(name),
        type: :dir,
        kind: {:page, fqs, idx * page_size(), length(chunk)}
      }
    end)
  end

  defp item_children(id) do
    doc = item_doc(id)
    item = Item.from_solr(doc)
    modified = doc["updated_at_dt"]
    urls = doc["image_service_urls_ss"] || []
    width = urls |> length() |> Integer.to_string() |> String.length() |> max(3)

    images =
      urls
      |> Enum.with_index(1)
      |> Enum.map(fn {url, idx} ->
        %Entry{
          name: "#{idx |> Integer.to_string() |> String.pad_leading(width, "0")}.jpg",
          type: :file,
          kind: :image,
          content_type: "image/jpeg",
          image_service_url: url,
          modified: modified
        }
      end)

    volumes =
      if doc["multi_part_work_b"] do
        solr(
          q: "*:*",
          fq: ~s(parent_id_s:"#{escape(id)}"),
          fl: @item_fl,
          sort: "parent_idx_i asc",
          rows: 1000
        )
        |> docs()
        |> Enum.with_index(1)
        |> Enum.map(fn {child, idx} ->
          entry = item_entry(child)
          prefix = idx |> Integer.to_string() |> String.pad_leading(2, "0")
          %{entry | name: "#{prefix} #{entry.name}"}
        end)
      else
        []
      end

    warning =
      case doc["content_warning_s"] do
        warning when is_binary(warning) and warning != "" ->
          [text_file("CONTENT WARNING.txt", warning <> "\n", modified)]

        _ ->
          []
      end

    warning ++
      images ++
      volumes ++
      [
        %{
          text_file("metadata.json", metadata_json(item, doc), modified)
          | content_type: "application/json"
        }
      ]
  end

  ## Items

  defp item_entries(fqs, start, rows) do
    solr(
      q: "*:*",
      fq: fqs,
      fl: @item_fl,
      sort: "title_sort asc, id asc",
      start: start,
      rows: rows
    )
    |> docs()
    |> Enum.map(&item_entry/1)
  end

  defp item_entry(doc) do
    %Entry{
      name: "#{sanitize(title(doc), 80)} [#{String.slice(doc["id"], 0, 8)}]",
      type: :dir,
      kind: {:item, doc["id"]},
      modified: doc["updated_at_dt"] || doc["digitized_at_dt"]
    }
  end

  defp item_doc(id) do
    solr(q: "*:*", fq: ~s(id:"#{escape(id)}"), rows: 1) |> docs() |> List.first()
  end

  defp title(doc) do
    case doc["title_ss"] do
      [title | _] when is_binary(title) and title != "" -> title
      _ -> "Untitled"
    end
  end

  ## Generated text files

  defp text_file(name, content, modified \\ nil) do
    %Entry{
      name: name,
      type: :file,
      kind: :text,
      content: content,
      content_type: "text/plain; charset=utf-8",
      size: byte_size(content),
      modified: modified
    }
  end

  defp readme do
    """
    Princeton University Library Digital Collections
    ================================================

    A read-only view of the digital collections as a file system.

      Collections/<Collection>/<Format>/<Item title> [id]/

    Large formats are split into numbered folders of #{page_size()} items,
    ordered by title. Each item folder holds its images (001.jpg, 002.jpg,
    ..., up to 2000 pixels on the long edge) and a metadata.json with its
    catalog record and a link back to the item page, where the full-resolution
    images can be viewed and downloaded.

    Images are fetched on demand from the IIIF image server, so the first
    download of each file can take a few seconds.

    #{site_url()}
    """
  end

  defp about_collection(doc) do
    title = doc["title_ss"] |> List.wrap() |> List.first()
    tagline = doc["tagline_txtm"] |> List.wrap() |> List.first()
    summary = (doc["summary_txtm"] |> List.wrap() |> List.first() || "") |> strip_html()

    [
      title,
      String.duplicate("=", String.length(title || "")),
      tagline,
      summary,
      "#{site_url()}/collections/#{doc["authoritative_slug_s"]}"
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  defp metadata_json(item, doc) do
    fields =
      for {_category, fields} <- Item.metadata_detail_categories(),
          {field, label} <- fields,
          value <- [Map.get(item, field)],
          value not in [nil, "", []],
          do: {label, value}

    Jason.OrderedObject.new(
      [
        {"id", doc["id"]},
        {"url", site_url() <> item.url}
      ] ++ fields ++ [{"summary", item.summary}]
    )
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  defp page_size, do: Application.get_env(:dpul_collections, :dav_page_size, 500)

  defp site_url, do: DpulCollectionsWeb.Endpoint.url()

  ## Helpers

  # Accepts list values (e.g. `fq: [..]`) and sends them as repeated params.
  defp solr(params) do
    params = Enum.flat_map(params, fn {k, v} -> v |> List.wrap() |> Enum.map(&{k, &1}) end)
    {:ok, response} = Client.query(Index.read_index(), params: params)
    response.body
  end

  defp docs(body), do: body["response"]["docs"]

  # Solr returns facets as a flat [value, count, value, count, ...] list; the
  # facet.missing bucket comes back with a nil value.
  defp facet_counts(body, field) do
    body["facet_counts"]["facet_fields"][field]
    |> Enum.chunk_every(2)
    |> Enum.reject(fn [_value, count] -> count == 0 end)
    |> Map.new(fn [value, count] -> {value, count} end)
  end

  defp escape(value), do: String.replace(value, ~r/(["\\])/, "\\\\\\1")

  defp short(title) do
    title = String.trim(title)

    if String.length(title) > 24,
      do: String.slice(title, 0, 24) |> String.trim() |> Kernel.<>("…"),
      else: title
  end

  defp strip_html(html), do: html |> String.replace(~r/<[^>]*>/, "") |> String.trim()

  @doc """
  Make a string safe to use as a file or folder name on macOS, Windows and
  Linux: no path separators or reserved characters, no leading dots, no
  trailing dots/spaces, bounded length.
  """
  def sanitize(name, max \\ 120) do
    name
    |> String.replace(~r/[\/\\:*?"<>|\x00-\x1F]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.trim_leading(".")
    |> String.slice(0, max)
    |> String.trim_trailing()
    |> String.trim_trailing(".")
    |> case do
      "" -> "Untitled"
      name -> name
    end
  end
end
