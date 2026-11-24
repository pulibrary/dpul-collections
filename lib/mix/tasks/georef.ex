defmodule Mix.Tasks.Georef do
  @shortdoc "Georeference a IIIF map manifest with a local VLM + OSM"
  @moduledoc """
  Usage:

      mix georef URL [--canvases 0,2] [--out tmp/georef/name] [--no-refine]

  URL is a IIIF manifest or a maps.princeton.edu catalog URL. Writes
  `<out>.json` (IIIF Georeference AnnotationPage) and `<out>.report.json`
  (per-canvas debug data used by the evaluation scripts).
  """
  use Mix.Task

  alias DpulCollections.Georef

  @impl true
  def run(argv) do
    {opts, [url], _} =
      OptionParser.parse(argv,
        strict: [
          canvases: :string,
          out: :string,
          refine: :boolean,
          threshold: :float,
          min_label_fraction: :float,
          labels_first: :boolean
        ]
      )

    Mix.Task.run("app.config")
    Application.ensure_all_started(:req)

    run_opts =
      [refine: Keyword.get(opts, :refine, true)]
      |> maybe_put(:threshold, opts[:threshold])
      |> maybe_put(:min_label_fraction, opts[:min_label_fraction])
      |> maybe_put(:labels_first, opts[:labels_first])
      |> maybe_put(
        :canvases,
        opts[:canvases] && Enum.map(String.split(opts[:canvases], ","), &String.to_integer/1)
      )

    {time, result} = :timer.tc(fn -> Georef.run(url, run_opts) end)

    out =
      opts[:out] ||
        Path.join(
          "tmp/georef",
          url |> String.split("/") |> Enum.reject(&(&1 in ["", "manifest"])) |> List.last()
        )

    File.mkdir_p!(Path.dirname(out))
    File.write!(out <> ".json", Jason.encode!(result.annotation, pretty: true))
    File.write!(out <> ".report.json", Jason.encode!(report(result), pretty: true))

    for r <- result.results do
      Mix.shell().info(
        "#{r.label}: #{r.status} labels=#{length(r.labels)} located=#{length(r.located)} " <>
          "label_hits=#{inspect(r[:label_hits])} gcps=#{length(r.gcps)}" <>
          if(r.status == :ok,
            do:
              " scale=#{Float.round(r.scale, 4)}m/px rms=#{Float.round(rms(r.residuals), 1)}m" <>
                if(r[:method], do: " (#{r[:method]})", else: ""),
            else: ""
          )
      )
    end

    Mix.shell().info("wrote #{out}.json in #{div(time, 1_000_000)}s")
    # Served by GeorefController in dev (CORS-enabled) so Allmaps can fetch it.
    name = Path.basename(out)

    if String.starts_with?(Path.expand(out), Path.expand("tmp/georef")) do
      url = "http://localhost:4000/georef/#{name}.json"
      Mix.shell().info("Allmaps: https://viewer.allmaps.org/?url=" <> URI.encode_www_form(url))
    end
  end

  defp maybe_put(kw, _k, nil), do: kw
  defp maybe_put(kw, k, v), do: Keyword.put(kw, k, v)

  defp rms([]), do: 0.0
  defp rms(r), do: :math.sqrt(Enum.sum(Enum.map(r, &(&1 * &1))) / length(r))

  defp report(result) do
    %{
      manifest: result.manifest.id,
      label: result.manifest.label,
      bbox: Tuple.to_list(result.osm.bbox),
      canvases:
        Enum.map(result.results, fn r ->
          %{
            id: r.canvas.id,
            label: r.label,
            part: r.part,
            width: r.canvas.width,
            height: r.canvas.height,
            service: r.canvas.service_id,
            status: r.status,
            located:
              Enum.map(r.located, fn l ->
                %{
                  label: l.label,
                  keys: Tuple.to_list(l.keys),
                  px: Tuple.to_list(l.px),
                  coarse_px: Tuple.to_list(l.coarse_px)
                }
              end),
            mask: Enum.map(r.mask, &Tuple.to_list/1),
            gcps:
              Enum.map(r.gcps, fn g ->
                %{label: g.label, px: Tuple.to_list(g.px), lonlat: g.lonlat}
              end),
            residuals: r[:residuals],
            method: r[:method] || (r.status == :ok && :junctions) || nil,
            labels:
              Enum.map(r.labels, fn l ->
                %{
                  name: l.name,
                  key: l.key,
                  angle: l.angle,
                  source: l.source,
                  px: Tuple.to_list(l.px)
                }
              end),
            label_hits: r[:label_hits],
            scale_m_per_px: r[:scale],
            printed_scale_ft: r[:printed_scale_ft],
            rough: r[:rough] && Map.take(r[:rough], [:label_hits, :seed_inliers]),
            transform: r[:transform],
            projection: r[:projection]
          }
        end)
    }
  end
end
