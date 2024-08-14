defmodule DpulCollections.IndexingPipeline.FiggyHydratorIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.{FiggyProducer, FiggyHydrator}
  alias DpulCollections.IndexingPipeline

  test "message acknowledgement" do
    pid = self()

    :telemetry.attach(
      "ack-handler",
      [:figgy_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, figgy_producer_pid} = FiggyProducer.start_link()

    {:ok, _hydrator} =
      FiggyHydrator.start_link(0, FiggyTestProducer, {figgy_producer_pid, self()}, 1)

    FiggyTestProducer.process(1)
    assert_receive {:ack_done}

    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == "3cb7627b-defc-401b-9959-42ebc4488f74"
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == ~U[2018-03-09 20:19:33.414040Z]

    assert %{
             "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
             "internal_resource" => "EphemeraTerm"
           } = cache_entry.data
  end
end
