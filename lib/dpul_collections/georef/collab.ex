defmodule DpulCollections.Georef.Collab do
  @moduledoc """
  Collaborative georeferencing: volunteers' browsers do the fitting
  (assets/js/georeferencer/) and this module only hands them inputs and
  keeps what they make.

  Inputs per map part: the sheet image (proxied, so the browser may read its
  pixels), the part's outline and OCR'd labels, and the town's OpenStreetMap
  streets in local metres. These come from `mix georef` reports for now
  (`:collab_runs`); the part splitting and OCR are the next steps to move
  into the browser.

  Results are `Contribution`s, credited to the signed-in user and
  downloadable as IIIF Georeference Annotations, per part or merged per atlas.
  """

  import Ecto.Query
  alias DpulCollections.Repo
  alias DpulCollections.Georef
  alias DpulCollections.Georef.{Annotation, Geometry, Osm}
  alias DpulCollections.Georef.Collab.Contribution

  # OSM highway types drawn on the sheets (priv/georef/corridor.py DRAWN)
  @drawn ~w(residential primary secondary tertiary unclassified living_street trunk
            primary_link secondary_link tertiary_link road)
  @rails ~w(rail abandoned disused razed)

  def runs do
    Application.get_env(:dpul_collections, DpulCollections.Georef, [])
    |> Keyword.get(:collab_runs, [
      "tmp/georef_scratch/runs/portal6",
      "tmp/georef_scratch/runs/figgy2"
    ])
  end

  # Atlases ---------------------------------------------------------------------

  @doc """
  Every atlas: queued ones (parts from the volunteers' results so far), then
  the server runs' reports, as %{id, label, parts, server_ok}.
  """
  def list_atlases do
    queued =
      for a <- Repo.all(DpulCollections.Georef.Collab.Atlas) do
        parts = DpulCollections.Georef.Collab.Queue.parts(a)

        %{
          id: a.id,
          label: a.label,
          parts: length(parts),
          server_ok: Enum.count(parts, &(&1["status"] == "ok")),
          source: :queue
        }
      end

    ids = MapSet.new(queued, & &1.id)
    queued ++ Enum.reject(report_atlases(), &MapSet.member?(ids, &1.id))
  end

  defp report_atlases do
    for dir <- runs(),
        path <- Path.wildcard(Path.join(dir, "*.report.json")),
        r = report(path),
        do: %{
          id: Path.basename(path, ".report.json"),
          label: r["label"],
          parts: length(r["canvases"]),
          server_ok: Enum.count(r["canvases"], &(&1["status"] == "ok")),
          source: :report
        }
  end

  def atlas(id) do
    case valid_id?(id) && DpulCollections.Georef.Collab.Queue.get_atlas(id) do
      %DpulCollections.Georef.Collab.Atlas{} = a ->
        a
        |> DpulCollections.Georef.Collab.Atlas.base()
        |> Map.put("canvases", DpulCollections.Georef.Collab.Queue.parts(a))

      _ ->
        report_atlas(id)
    end
  end

  defp valid_id?(id), do: is_binary(id) and id =~ ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,80}\z/

  defp report_atlas(id) do
    # Figgy UUIDs and portal ids ("princeton-k0698b430"); never a path
    if id =~ ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,80}\z/ do
      Enum.find_value(runs(), fn dir ->
        path = Path.join(dir, "#{id}.report.json")
        if File.regular?(path), do: report(path) |> Map.put("id", id)
      end)
    end
  end

  # reports are a few MB; keep the parsed one until the file changes
  defp report(path) do
    mtime = File.stat!(path).mtime
    key = {__MODULE__, :report, path}

    case :persistent_term.get(key, nil) do
      {^mtime, r} ->
        r

      _ ->
        r = path |> File.read!() |> Jason.decode!()
        :persistent_term.put(key, {mtime, r})
        r
    end
  end

  def projection(atlas), do: atlas["bbox"] |> List.to_tuple() |> Geometry.projection()

  # Inputs for the browser ---------------------------------------------------------

  @doc """
  Everything the browser needs to fit part `i` of an atlas: the part, its
  labels, where each label's street is, every drawn street and railway (for
  the corridor score), the atlas's fitted scales, and the neighbouring parts'
  current placements for context.
  """
  def sheet_input(atlas, i) do
    c = Enum.at(atlas["canvases"], i)
    latest = latest_by_part(atlas["id"])

    %{
      atlas: %{id: atlas["id"], label: atlas["label"], manifest: atlas["manifest"]},
      index: i,
      projection: projection(atlas),
      canvas: %{
        id: c["id"],
        label: c["label"],
        part: c["part"],
        service: c["service"],
        width: c["width"],
        height: c["height"],
        mask: c["mask"],
        printed_scale_ft: c["printed_scale_ft"],
        labels: for(l <- c["labels"], do: Map.take(l, ~w(name key px height angle source)))
      },
      # the server prototype's own fit, shown only as a reference outline
      server: server_fit(c),
      osm: "/georeferencer/atlas/#{atlas["id"]}/osm.json?v=2",
      # the town's own name: title lettering, not a street (Georef.drop_title_town)
      exclude_keys: [Osm.normalize(Georef.town_name(%{label: atlas["label"]}))],
      scales:
        for(
          x <- atlas["canvases"],
          x["status"] == "ok",
          s = x["scale_m_per_px"],
          is_number(s),
          do: s
        ),
      neighbours:
        for(
          {x, j} <- Enum.with_index(atlas["canvases"]),
          j != i,
          t = current_transform(x, latest),
          t != nil,
          do: %{index: j, label: x["label"], mask: x["mask"], transform: t}
        )
    }
  end

  defp server_fit(%{"status" => "ok", "transform" => t}), do: t
  defp server_fit(_), do: nil

  # a volunteer's latest word beats the server's fit
  defp current_transform(c, latest) do
    case latest[{c["id"], c["part"]}] do
      %{verdict: "placed", transform: t} -> t
      %{verdict: "cannot"} -> nil
      nil -> server_fit(c)
    end
  end

  defp r1(xs), do: Enum.map(xs, &Float.round(&1 * 1.0, 1))

  # the gazetteer the server run used, with the renames it learned
  defp osm(atlas) do
    cached({:osm, atlas["id"]}, fn ->
      osm = atlas["bbox"] |> List.to_tuple() |> Osm.load()

      case atlas["renames"] do
        %{"table" => t} when map_size(t) > 0 -> Osm.with_aliases(osm, t)
        _ -> osm
      end
    end)
  end

  @doc """
  The town for the browser, fetched once per atlas: every named feature
  (street, railway, waterway, building; with the renames the server run
  learned) as {key: {kind, segments}} for matching OCR'd names and checking
  labels, plus the drawn streets and railways for the corridor score.
  """
  def osm_payload(atlas) do
    cached({:payload_v2, atlas["id"]}, fn ->
      osm = osm(atlas)

      %{
        # where two named streets cross (junction seeds): [key1, key2, x, y]
        crossings:
          for(
            %{keys: {a, b}, xy: {x, y}} <- osm.intersections,
            do: [a, b, Float.round(x * 1.0, 1), Float.round(y * 1.0, 1)]
          ),
        groups:
          Map.new(osm.groups, fn {k, g} ->
            {k,
             %{
               kind: g.kind,
               segs: g.segments |> Enum.flat_map(fn {{a, b}, {c, d}} -> [a, b, c, d] end) |> r1()
             }}
          end),
        lines: lines(atlas)
      }
      |> Jason.encode!()
    end)
  end

  @doc "Drawn streets (kind 1) and railways (kind 2) as [kind, x0, y0, x1, y1, ...] in metres."
  def lines(atlas) do
    cached({:lines, atlas["id"]}, fn ->
      p = projection(atlas)

      osm(atlas).path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.flat_map(fn
        %{"geometry" => %{"type" => "LineString", "coordinates" => cs}, "properties" => pr} ->
          kind =
            cond do
              pr["railway"] in @rails -> 2
              pr["highway"] in @drawn -> 1
              true -> nil
            end

          if kind,
            do: [[kind | cs |> Enum.flat_map(&Tuple.to_list(Geometry.to_xy(p, &1))) |> r1()]],
            else: []

        _ ->
          []
      end)
      |> Enum.to_list()
    end)
  end

  defp cached(key, fun) do
    key = {__MODULE__, key}

    case :persistent_term.get(key, nil) do
      nil -> fun.() |> tap(&:persistent_term.put(key, &1))
      v -> v
    end
  end

  def ocr_model_dir do
    Application.get_env(:dpul_collections, DpulCollections.Georef, [])
    |> Keyword.get(:ocr_web_dir, Path.expand("~/.cache/dpul_georef/ocr_web"))
  end

  # The sheet image the browser analyses: 3000 px wide, like the server helpers.
  def image_url(service), do: service <> "/full/3000,/0/default.jpg"

  def allowed_service?(service) do
    case URI.parse(service) do
      %URI{scheme: "https", host: "iiif-cloud.princeton.edu"} -> true
      _ -> false
    end
  end

  # Contributions ---------------------------------------------------------------

  def save(user, atlas, i, attrs),
    do: save_part(user, atlas, Enum.at(atlas["canvases"], i), attrs)

  @doc "Save a contribution for one part (`c`: the canvas map with this part's mask and number)."
  def save_part(user, atlas, c, attrs) do
    attrs =
      Map.merge(attrs, %{
        "atlas_id" => atlas["id"],
        "atlas_label" => atlas["label"],
        "canvas_id" => c["id"],
        "canvas_label" => c["label"],
        "part" => c["part"] || 1,
        "projection" => projection(atlas)
      })

    attrs =
      if attrs["verdict"] == "placed",
        do: Map.put(attrs, "annotation", annotation(atlas, c, attrs["transform"], user)),
        else: attrs

    %Contribution{} |> Contribution.changeset(attrs, user) |> Repo.insert()
  end

  def list_for_user(user) do
    Repo.all(
      from c in Contribution, where: c.user_id == ^user.id, order_by: [desc: c.inserted_at]
    )
  end

  def get!(id), do: Repo.get!(Contribution, id)

  @doc "Latest contribution per {canvas_id, part} of an atlas."
  def latest_by_part(atlas_id) do
    Repo.all(from c in Contribution, where: c.atlas_id == ^atlas_id, order_by: c.inserted_at)
    |> Map.new(&{{&1.canvas_id, &1.part}, &1})
  end

  def counts_by_atlas do
    Repo.all(
      from c in Contribution,
        group_by: c.atlas_id,
        select: {c.atlas_id, count(fragment("distinct (?, ?)", c.canvas_id, c.part))}
    )
    |> Map.new()
  end

  @doc """
  The atlas's georeferencing as one AnnotationPage: each part's latest
  volunteer result, else the server prototype's fit.
  """
  def atlas_page(atlas) do
    latest = latest_by_part(atlas["id"])
    base = atlas["manifest"] <> "/georef-collab"

    items =
      atlas["canvases"]
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {c, n} ->
        case latest[{c["id"], c["part"]}] do
          %{verdict: "placed", annotation: a} ->
            [Map.put(a, "id", "#{base}/#{n}")]

          %{verdict: "cannot"} ->
            []

          nil ->
            if t = server_fit(c), do: [annotation(atlas, c, t, nil, "#{base}/#{n}")], else: []
        end
      end)

    %{
      "@context" => [
        "http://iiif.io/api/extension/georef/1/context.json",
        "http://iiif.io/api/presentation/3/context.json"
      ],
      "id" => base,
      "type" => "AnnotationPage",
      "items" => items
    }
  end

  @doc "IIIF Georeference Annotation for a part placed by `t` ({a, b, tx, ty}, canvas px -> m)."
  def annotation(atlas, c, t, user, id \\ nil) do
    t = %{a: t["a"], b: t["b"], tx: t["tx"], ty: t["ty"]}
    p = projection(atlas)
    mask = Enum.map(c["mask"], fn [x, y] -> {x, y} end)

    # control points: the outline's corners (a similarity needs only two;
    # four keep any viewer's first-order fit exact)
    {xs, ys} = Enum.unzip(mask)
    {x0, x1, y0, y1} = {Enum.min(xs), Enum.max(xs), Enum.min(ys), Enum.max(ys)}

    gcps =
      for px <- [{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}],
          do: %{
            px: px,
            lonlat: Geometry.to_lonlat(p, Geometry.transform(t, px)),
            label: "outline"
          }

    canvas = %{
      id: c["id"],
      service_id: c["service"],
      service_type: "ImageService2",
      width: c["width"],
      height: c["height"],
      px_scale: 1
    }

    manifest = %{id: atlas["manifest"], label: atlas["label"]}

    Annotation.annotation(
      manifest,
      %{canvas: canvas, mask: mask, gcps: gcps},
      id || c["id"] <> "/georef"
    )
    |> Map.put(
      "generator",
      if(user,
        do: %{
          "type" => "Software",
          "name" => "DPUL collaborative georeferencer (in the contributor's browser)"
        },
        else: %{"type" => "Software", "name" => "DPUL georef server prototype"}
      )
    )
    |> then(fn a ->
      if user,
        do: Map.put(a, "creator", %{"type" => "Person", "id" => "urn:dpul:user:#{user.id}"}),
        else: a
    end)
  end
end
