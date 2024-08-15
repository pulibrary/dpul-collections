defmodule DpulCollections.IndexingPipeline.FiggyHydratorIntegrationTest do
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.FiggyHydrator
  alias DpulCollections.IndexingPipeline

  def start_producer do
    pid = self()

    :telemetry.attach(
      "ack-handler-#{pid |> :erlang.pid_to_list()}",
      [:figgy_producer, :ack, :done],
      fn _event, _, _, _ -> send(pid, {:ack_done}) end,
      nil
    )

    {:ok, hydrator} =
      FiggyHydrator.start_link(0, FiggyTestProducer, {self()}, 1)

    hydrator
  end

  test "message acknowledgement" do
    hydrator = start_producer()

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

    hydrator |> Broadway.stop(:normal)
  end

  test "loads a marker from the database on startup" do
    # Create a marker
    IndexingPipeline.write_hydrator_marker(
      0,
      ~U[2018-03-09 20:19:33.414040Z],
      "3cb7627b-defc-401b-9959-42ebc4488f74"
    )

    # Start the producer
    hydrator = start_producer()
    # Make sure the first record that comes back is what we expect
    FiggyTestProducer.process(1)
    assert_receive {:ack_done}
    cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
    assert cache_entry.record_id == "69990556-434c-476a-9043-bbf9a1bda5a4"
    assert cache_entry.cache_version == 0
    assert cache_entry.source_cache_order == ~U[2018-03-09 20:19:34.465203Z]
    hydrator |> Broadway.stop(:normal)
  end
end
