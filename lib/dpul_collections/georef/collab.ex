defmodule DpulCollections.Georef.Collab do
  @moduledoc """
  Collaborative georeferencing: volunteers' browsers do the fitting
  (assets/js/georeferencer/) and this module only hands them inputs and
  keeps what they make.

  The queue (`Collab.Queue`) hands each sheet to a volunteer's browser, which
  finds the sheet's parts, reads it, and fits each part to the town's
  OpenStreetMap streets; the server prepares the town (search box, OSM
  extract) and keeps the results. Parts the browsers aren't sure of go to
  people (`Collab.Review`).

  Results are `Contribution`s, credited to the signed-in user and
  downloadable as IIIF Georeference Annotations, per part or merged per atlas.
  """

  import Ecto.Query
  alias DpulCollections.Repo
  alias DpulCollections.Georef.{Annotation, Geometry, Osm}
  alias DpulCollections.Georef.Collab.{Atlas, Contribution, Queue, Review}

  # OSM highway types drawn on the sheets
  @drawn ~w(residential primary secondary tertiary unclassified living_street trunk
            primary_link secondary_link tertiary_link road)
  @rails ~w(rail abandoned disused razed)

  # Atlases ---------------------------------------------------------------------

  @doc "Every queued atlas, as %{id, label, parts, placed}."
  def list_atlases do
    for a <- Repo.all(Atlas) do
      parts = Queue.parts(a)

      %{
        id: a.id,
        label: a.label,
        parts: length(parts),
        placed: Enum.count(parts, &(&1["status"] == "ok"))
      }
    end
  end

  @doc "A queued atlas with its parts (`\"canvases\"`), or nil."
  def atlas(id) do
    case valid_id?(id) && Queue.get_atlas(id) do
      %Atlas{} = a ->
        a
        |> Atlas.base()
        |> Map.put("canvases", Queue.parts(a))

      _ ->
        nil
    end
  end

  defp valid_id?(id), do: is_binary(id) and id =~ ~r/\A[A-Za-z0-9][A-Za-z0-9_-]{0,80}\z/

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
      projection: projection(atlas),
      canvas: %{
        service: c["service"],
        width: c["width"],
        mask: c["mask"],
        printed_scale_ft: c["printed_scale_ft"],
        labels: for(l <- c["labels"], do: Map.take(l, ~w(name key px height)))
      },
      # the computer's placement, and what to make of it
      auto: c["transform"],
      auto_status: auto_status(c),
      osm: osm_url(atlas),
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
          do: %{mask: x["mask"], transform: t}
        )
    }
  end

  # placed: accepted by the server's check of a browser's result (Queue.checked)
  defp placed_fit(%{"status" => "ok", "transform" => t}), do: t
  defp placed_fit(_), do: nil

  # "ok" (placed), "guess" (unsure but its streets line up), "doubtful", or nil (no placement)
  defp auto_status(%{"status" => "ok"}), do: "ok"

  defp auto_status(%{"transform" => t} = c) when is_map(t),
    do: if(Review.lines_up?(c), do: "guess", else: "doubtful")

  defp auto_status(_), do: nil

  # a person's latest word beats the automatic fit
  defp current_transform(c, latest) do
    case decided(c, latest) do
      %{verdict: "placed", transform: t} -> t
      %{verdict: "cannot"} -> nil
      nil -> placed_fit(c)
    end
  end

  @doc """
  Where a part stands: `:by_person` (placed by someone), `:cannot` (someone
  said it can't be placed), `:auto` (placed by a browser) or `:unplaced`.
  """
  def part_state(c, latest) do
    case decided(c, latest) do
      %{verdict: "cannot"} -> :cannot
      %{verdict: "placed"} = l -> if human?(l), do: :by_person, else: :auto
      nil -> if c["status"] == "ok", do: :auto, else: :unplaced
    end
  end

  defp r1(xs), do: Enum.map(xs, &Float.round(&1 * 1.0, 1))

  # the gazetteer the server run used, with the renames it learned
  defp osm(atlas) do
    cached({:osm, atlas["id"]}, town_version(atlas), fn ->
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
    cached({:payload, atlas["id"]}, town_version(atlas), fn ->
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

  # drawn streets (kind 1) and railways (kind 2) as [kind, x0, y0, x1, y1, ...] in metres
  defp lines(atlas) do
    cached({:lines, atlas["id"]}, town_version(atlas), fn ->
      p = projection(atlas)

      osm(atlas).path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      # the extract holds only LineStrings (Osm exports --geometry-types=linestring)
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
      end)
      |> Enum.to_list()
    end)
  end

  # what the town's data depends on: its box, the renames learned so far, and
  # the payload's format (bump @town_format when name matching changes)
  @town_format 4
  defp town_version(atlas), do: :erlang.phash2({@town_format, atlas["bbox"], atlas["renames"]})

  @doc "The town's streets for the browser; the URL changes with the data, so browsers refetch."
  def osm_url(atlas),
    do: "/georeferencer/atlas/#{atlas["id"]}/osm.json?v=#{town_version(atlas)}"

  # one entry per atlas and kind, rebuilt when its version changes
  defp cached(key, version, fun) do
    key = {__MODULE__, key}

    case :persistent_term.get(key, nil) do
      {^version, v} -> v
      _ -> fun.() |> tap(&:persistent_term.put(key, {version, &1}))
    end
  end

  def ocr_model_dir, do: Path.join(DpulCollections.Georef.cache_dir(), "ocr_web")

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

  @doc """
  Whether a person decided this part: marked it can't be placed, adjusted it,
  or confirmed it in the editor (the queue's own saves carry the job timings).
  """
  def human?(%Contribution{verdict: "cannot"}), do: true
  def human?(%Contribution{method: "adjusted"}), do: true
  def human?(%Contribution{compute: compute}), do: not Map.has_key?(compute || %{}, "timings")

  # the part's latest contribution that still stands: a person's, or an
  # automatic one while the server's check (Queue.checked) agrees the part is placed
  defp decided(c, latest) do
    case latest[{c["id"], c["part"]}] do
      nil -> nil
      contribution -> if human?(contribution) or c["status"] == "ok", do: contribution
    end
  end

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
        case decided(c, latest) do
          %{verdict: "placed", annotation: a} ->
            [Map.put(a, "id", "#{base}/#{n}")]

          %{verdict: "cannot"} ->
            []

          nil ->
            if t = placed_fit(c), do: [annotation(atlas, c, t, nil, "#{base}/#{n}")], else: []
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

    canvas = %{id: c["id"], service_id: c["service"], width: c["width"], height: c["height"]}
    manifest = %{id: atlas["manifest"], label: atlas["label"]}

    Annotation.annotation(manifest, canvas, mask, gcps, id || c["id"] <> "/georef")
    |> Map.put("generator", %{
      "type" => "Software",
      "name" => "DPUL collaborative georeferencer (in a volunteer's browser)"
    })
    |> then(fn a ->
      if user,
        do: Map.put(a, "creator", %{"type" => "Person", "id" => "urn:dpul:user:#{user.id}"}),
        else: a
    end)
  end
end
