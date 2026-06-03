defmodule DpulCollections.IndexingPipeline.Figgy.IndexingProducerSource do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source

  def processor_marker_key() do
    "figgy_indexer"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, cache_version) do
    IndexingPipeline.get_transformation_cache_entries_since!(
      last_queried_marker,
      total_demand,
      cache_version
    )
  end

  def init(%{cache_version: cache_version}) do
    # Listen for batch_processor stops, so we know when a transformer we care about
    # is done.
    producer_pid = self()

    :telemetry.attach(
      "transformation-listener-#{producer_pid |> :erlang.pid_to_list()}",
      [:broadway, :batch_processor, :stop],
      &handle_batch_closed(&1, &2, &3, &4, cache_version),
      %{producer_pid: producer_pid}
    )
  end

  defp handle_batch_closed(
         _event,
         _measurements,
         %{context: %{type: :figgy_transformer, cache_version: cache_version}},
         %{producer_pid: producer_pid},
         cache_version
       ) do
    send(producer_pid, :check_for_updates)
  end

  defp handle_batch_closed(_event, _measurements, _metadata, _config, _cache_version), do: nil
end
