defmodule DpulCollections.OpenTelemetrySampler do
  @moduledoc """
  Sampler to drop traces we don't wanna see.
  Right now it gets rid of ecto queries that have no parent span (indexing pipeline polling),
  static assets, socket stuff, and some noisy Clover events.
  Docs: https://opentelemetry.io/docs/languages/erlang/sampling/
  """
  @behaviour :otel_sampler

  @ignored_events ~w(changedCanvas)

  @impl :otel_sampler
  def setup(_opts) do
    %{static_paths: DpulCollectionsWeb.static_paths()}
  end

  @impl :otel_sampler
  def description(_config), do: "DpulCollections.OpenTelemetrySampler"

  @impl :otel_sampler
  def should_sample(ctx, _trace_id, _links, span_name, _span_kind, attributes, config) do
    tracestate = ctx |> OpenTelemetry.Tracer.current_span_ctx() |> OpenTelemetry.Span.tracestate()

    if ignored_event?(span_name) or drop?(attributes, config) do
      {:drop, [], tracestate}
    else
      {:record_and_sample, [], tracestate}
    end
  end

  # ignore any events we don't want, right now just changedCanvas
  defp ignored_event?(span_name) when is_binary(span_name) do
    case String.split(span_name, ".handle_event#", parts: 2) do
      [_module, event] -> event in @ignored_events
      _ -> false
    end
  end

  defp ignored_event?(_span_name), do: false

  # Drop db events - this sampler only gets called on parents, parent-less db
  # events aren't useful to look at anyways.
  defp drop?(%{"db.type": _}, _config), do: true
  defp drop?(%{"url.path": path}, config), do: ignored_path?(path, config.static_paths)
  defp drop?(_attributes, _config), do: false

  defp ignored_path?("/phoenix/live_reload/" <> _, _static_paths), do: true
  defp ignored_path?("/live/websocket", _static_paths), do: true
  defp ignored_path?("/live/longpoll", _static_paths), do: true
  defp ignored_path?("/health", _static_paths), do: true

  defp ignored_path?("/" <> path, static_paths) do
    [top_level | _] = String.split(path, "/", parts: 2)
    top_level in static_paths
  end

  defp ignored_path?(_, _), do: false
end
