defmodule DpulCollections.IndexingPipeline.FiggyProducerTest do
  alias DpulCollections.IndexingPipeline.FiggyHydrator
  use DpulCollections.DataCase

  alias DpulCollections.IndexingPipeline.{FiggyProducer, FiggyResource}
  alias DpulCollections.IndexingPipeline

  describe "FiggyProducer" do
    test "handle_demand/2 with initial state and demand > 1 returns figgy resources" do
      initial_state = FiggyProducer.init(0) |> elem(1)
      {:noreply, messages, new_state} = FiggyProducer.handle_demand(2, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)

      assert ids == [
               "3cb7627b-defc-401b-9959-42ebc4488f74",
               "69990556-434c-476a-9043-bbf9a1bda5a4"
             ]

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [
            {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"},
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 with consecutive state returns a new record" do
      initial_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"},
          pulled_records: [
            {~U[2018-03-09 20:19:33.414040Z], "3cb7627b-defc-401b-9959-42ebc4488f74"},
            {~U[2018-03-09 20:19:34.465203Z], "69990556-434c-476a-9043-bbf9a1bda5a4"}
          ],
          acked_records: []
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids = ["47276197-e223-471c-99d7-405c5f6c5285"]

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {
              ~U[2018-03-09 20:19:33.414040Z],
              "3cb7627b-defc-401b-9959-42ebc4488f74"
            },
            {
              ~U[2018-03-09 20:19:34.465203Z],
              "69990556-434c-476a-9043-bbf9a1bda5a4"
            },
            {
              ~U[2018-03-09 20:19:34.486004Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            }
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    test "handle_demand/2 when the marker record has been updated" do
      initial_state =
        %{
          # This is a manufactured marker.
          # This timestamp is set to be right before the actual record updated_at.
          last_queried_marker:
            {~U[2018-03-09 20:19:34.465204Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {~U[2018-03-09 20:19:34.465204Z], "47276197-e223-471c-99d7-405c5f6c5285"}
          ],
          acked_records: []
        }

      {:noreply, messages, new_state} = FiggyProducer.handle_demand(1, initial_state)

      ids = Enum.map(messages, fn %Broadway.Message{data: %FiggyResource{id: id}} -> id end)
      assert ids = ["47276197-e223-471c-99d7-405c5f6c5285"]

      expected_state =
        %{
          last_queried_marker:
            {~U[2018-03-09 20:19:34.486004Z], "47276197-e223-471c-99d7-405c5f6c5285"},
          pulled_records: [
            {
              ~U[2018-03-09 20:19:34.465204Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            },
            {
              ~U[2018-03-09 20:19:34.486004Z],
              "47276197-e223-471c-99d7-405c5f6c5285"
            }
          ],
          acked_records: []
        }

      assert new_state == expected_state
    end

    defmodule TestConsumer do
      def start_link(producer) do
        GenStage.start_link(__MODULE__, {producer, self()})
      end

      def init({producer, owner}) do
        {:consumer, %{owner: owner, subscription: nil}, subscribe_to: [producer]}
      end

      def handle_subscribe(:producer, _options, from, state) do
        new_state = %{state | subscription: from}
        {:manual, new_state}
      end

      def handle_events(events, _from, state) do
        send(state.owner, {:received, events})
        {:noreply, [], state.owner}
      end

      def handle_cast({:request, demand}, state) do
        GenStage.ask(state.subscription, demand)
        {:noreply, [], state}
      end

      def request(pid, demand) do
        GenServer.cast(pid, { :request, demand })
      end
    end

    test "integration test" do
      {:ok, stage} = FiggyProducer.start_link()
      {:ok, cons} = TestConsumer.start_link(stage)
      TestConsumer.request(cons, 1)

      assert_receive {:received, _messages}

      # The test consumer will also stop, since it is subscribed to the stage
      GenStage.stop(stage)
    end

    defmodule FiggyTestProducer do
      use GenStage

      def start_link() do
        GenStage.start_link(__MODULE__, nil, name: __MODULE__)
      end

      @impl GenStage
      def init({producer_stage, owner}) do
        {:ok, cons} = TestConsumer.start_link(producer_stage)
        {:producer, %{consumer: cons, owner: owner}}
      end

      def handle_demand(demand, state) do
        {:noreply, [], state}
      end

      def handle_info({:received, messages}, state) do
        send(state.owner, {:received, messages})
        {:noreply, messages, state}
      end

      def handle_cast({:fulfill_messages, demand}, state) do
        TestConsumer.request(state.consumer, demand)
        {:noreply, [], state}
      end

      def process(pid, demand) do
        GenServer.cast(pid, { :fulfill_messages, demand })
      end
    end

    test "message acknowledgement" do
      # Is there a way to put FiggyProducer into manual mode, so we can ask it
      # to deliver one?
      pid = self()
      :telemetry.attach("batch-finished-handler", [:broadway, :batch_processor, :stop], fn event, _, _, _ -> send(pid, {:batch_finished}) end, nil)
      {:ok, stage} = FiggyProducer.start_link()
      {:ok, hydrator} = FiggyHydrator.start_link(0, FiggyTestProducer, { stage, self() }, 1)
      Broadway.producer_names(FiggyHydrator) |> hd |> FiggyTestProducer.process(1)
      assert_receive {:received, _messages}
      assert_receive {:batch_finished}

      cache_entry = IndexingPipeline.list_hydration_cache_entries() |> hd
      assert cache_entry.record_id == "3cb7627b-defc-401b-9959-42ebc4488f74"
      assert cache_entry.cache_version == 0
      assert cache_entry.source_cache_order == ~U[2018-03-09 20:19:33.414040Z]

      assert %{
               "id" => "3cb7627b-defc-401b-9959-42ebc4488f74",
               "internal_resource" => "EphemeraTerm"
             } = cache_entry.data
      # send(stage, {:ack, :figgy_producer_ack, [], []})
      # :timer.sleep(1000)
      # Test if ProcessorMarker table has been updated
    end
  end
end
