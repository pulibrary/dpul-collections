defmodule DpulCollections.OpenTelemetryEcto do
  @moduledoc """
  A wrapper around OpenTelemetryEcto that filters out queries that are noisy.
  """

  def setup(event_prefix, config \\ []) do
    event = event_prefix ++ [:query]

    :telemetry.attach({OpentelemetryEcto, event}, event, &__MODULE__.handle_event/4, config)
  end

  @doc false
  # Don't trace all the indexing logic, it's just too much.
  def handle_event(_event, _measure, %{source: source}, _config)
      when source in [
             "orm_resources",
             "figgy_transformation_cache_entries",
             "figgy_hydration_cache_entries"
           ] do
    :ok
  end

  def handle_event(_event, _measure, %{options: [oban_conf: _]}, _config) do
    :ok
  end

  def handle_event(event, measure, meta, config) do
    OpentelemetryEcto.handle_event(event, measure, meta, config)
  end
end
