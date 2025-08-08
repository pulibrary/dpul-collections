defmodule DpulCollections.IndexingPipeline.Figgy.HydrationProducerSource do
  alias DpulCollections.IndexingPipeline
  @behaviour IndexingPipeline.DatabaseProducer.Source

  def init() do
    {:ok, _listen_ref} =
      Postgrex.Notifications.listen(DpulCollections.FiggyNotifier, "orm_resources_change")
  end

  def processor_marker_key() do
    "figgy_hydrator"
  end

  def get_cache_entries_since!(last_queried_marker, total_demand, _cache_version) do
    IndexingPipeline.get_figgy_resources_since!(last_queried_marker, total_demand)
  end
end
