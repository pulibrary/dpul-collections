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

  test "updates existing hydration cache entries, doesn't override newer ones" do
    # Create a hydration cache entry for a record that has a source_cache_order
    # in the future.
    IndexingPipeline.create_hydration_cache_entry(%{
      cache_version: 0,
      record_id: "3cb7627b-defc-401b-9959-42ebc4488f74",
      source_cache_order: ~U[2200-03-09 20:19:33.414040Z],
      data: %{}
    })

    # Process that past record.
    hydrator = start_producer()
    FiggyTestProducer.process(1)
    assert_receive {:ack_done}
    hydrator |> Broadway.stop(:normal)
    # Ensure there's only one hydration cache entry.
    entries = IndexingPipeline.list_hydration_cache_entries()
    assert length(entries) == 1
    # Ensure that entry has the source_cache_order we set at the beginning.
    entry = entries |> hd
    assert entry.source_cache_order == ~U[2200-03-09 20:19:33.414040Z]
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
