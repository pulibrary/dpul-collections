defmodule DpulCollections.IndexingPipeline.Coherence do
  alias DpulCollections.Solr
  alias DpulCollections.IndexingPipeline

  @spec index_parity?() :: boolean()
  def index_parity?() do
    Solr.Index.write_indexes()
    |> Enum.map(&index_progress_summary/1)
    |> is_new_cache_caught_up?()
  end

  @spec document_count_report() :: list()
  def document_count_report() do
    Solr.Index.write_indexes()
    |> Enum.map(fn index ->
      %{
        cache_version: index.cache_version,
        collection: index.collection,
        document_count: Solr.document_count(index)
      }
    end)
  end

  # Check the processor marker for the most recently indexed record.
  # Get the figgy timestamp for that record from its hydration cache entry.
  defp index_progress_summary(%{cache_version: cache_version}) do
    marker = IndexingPipeline.get_processor_marker!("figgy_indexer", cache_version)

    hydration_entry =
      IndexingPipeline.get_hydration_cache_entry!(
        marker.cache_record_id,
        cache_version
      )

    %{figgy_timestamp: hydration_entry.source_cache_order, cache_version: cache_version}
  end

  # if both indexes have hit the same figgy timestamp, we're caught up
  defp is_new_cache_caught_up?([
         %{figgy_timestamp: timestamps_are_equal},
         %{figgy_timestamp: timestamps_are_equal}
       ]) do
    true
  end

  # otherwise, if the more recent index has passed the older index, we're caught
  # up
  defp is_new_cache_caught_up?(index_progress_summaries) do
    version_sorted = Enum.sort_by(index_progress_summaries, & &1.cache_version)
    date_sorted = Enum.sort_by(index_progress_summaries, & &1.figgy_timestamp, DateTime)
    version_sorted == date_sorted
  end
end
