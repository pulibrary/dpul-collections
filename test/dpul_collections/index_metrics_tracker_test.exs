defmodule DpulCollections.IndexMetricsTrackerTest do
  alias DpulCollections.IndexingPipeline.IndexMetric
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  alias DpulCollections.IndexMetricsTracker
  use DpulCollections.DataCase

  describe "processor_durations/1" do
    setup do
      IndexMetricsTracker.reset()
      :ok
    end

    test "registers index times" do
      # Act
      # Send an ack done with acked_count 1, before anything - this should be
      # ignored
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key(),
          cache_version: 1
        }
      )

      IndexMetricsTracker.register_fresh_start(HydrationProducerSource, 1)
      # Send an ack done with acked_count 1, cache_version 1
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key(),
          cache_version: 1
        }
      )

      # Send an ack done with acked_count 1, cache_version 2. This should be
      # ignored.
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key(),
          cache_version: 2
        }
      )

      IndexMetricsTracker.register_polling_started(HydrationProducerSource, 1)
      # Send an ack done with unacked_count 1, this tracks ack but doesn't
      # finish.
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 1,
          processor_marker_key: HydrationProducerSource.processor_marker_key(),
          cache_version: 1
        }
      )

      # Send an ack done with unacked_count 0, this triggers an index time
      # create.
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key(),
          cache_version: 1
        }
      )

      [metric = %IndexMetric{} | rest] =
        IndexMetricsTracker.processor_durations(HydrationProducerSource)

      # There should only be one metric.
      assert length(rest) == 0
      # This is 0 because it takes less than a second to run.
      assert metric.duration == 0
      assert metric.records_acked == 3
      assert metric.cache_version == 1
    end
  end
end
