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
      IndexMetricsTracker.register_polling_started(HydrationProducerSource)
      [metric = %IndexMetric{}] = IndexMetricsTracker.index_times(HydrationProducerSource)

      # Assert
      # This is 0 because it takes less than a second to run.
      assert metric.duration == 0
    end
  end
end
