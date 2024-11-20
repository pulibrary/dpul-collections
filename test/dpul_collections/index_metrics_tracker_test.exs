defmodule DpulCollections.IndexMetricsTrackerTest do
  alias DpulCollections.IndexingPipeline.IndexMetric
  alias DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource
  alias DpulCollections.IndexMetricsTracker
  alias Phoenix.ActionClauseError
  use DpulCollections.DataCase

  describe "index_times/1" do
    test "registers index times" do
      # Act
      IndexMetricsTracker.register_fresh_index(HydrationProducerSource)
      # Send an ack done with acked_count 1
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key()
        }
      )
      IndexMetricsTracker.register_polling_started(HydrationProducerSource)
      # Send an ack done with unacked_count 0, this triggers an index time
      # create.
      :telemetry.execute(
        [:database_producer, :ack, :done],
        %{},
        %{
          acked_count: 1,
          unacked_count: 0,
          processor_marker_key: HydrationProducerSource.processor_marker_key()
        }
      )
      [metric = %IndexMetric{}] = IndexMetricsTracker.index_times(HydrationProducerSource)

      # Assert
      # This is 0 because it takes less than a second to run.
      assert metric.duration == 0
      assert metric.records_acked == 2
    end
  end
end
