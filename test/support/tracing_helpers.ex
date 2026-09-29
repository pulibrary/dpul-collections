defmodule DpulCollections.TracingHelpers do
  @moduledoc """
  Helpers for testing tracing stuff.
  Got this pattern from https://opentelemetry.io/docs/languages/erlang/testing/ and the tests in opentelemetry-erlang-contrib
  """

  defmacro __using__(_opts) do
    quote do
      require Record
      require OpenTelemetry.Tracer, as: Tracer

      Record.defrecordp(
        :span,
        Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
      )

      setup do
        :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
        :ok
      end
    end
  end
end
