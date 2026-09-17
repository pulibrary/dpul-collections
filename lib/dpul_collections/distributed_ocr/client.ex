defmodule DpulCollections.DistributedOcr.Client do
  alias DpulCollections.DistributedOcr.Host
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, %{processing: nil}, {:continue, :start_loop}}
  end

  def handle_continue(:start_loop, state) do
    send(self(), :check_for_updates)
    {:noreply, state}
  end

  def handle_info(:check_for_updates, state) do
    case Host.fetch_job() do
      {:ok, job} ->
        GenServer.cast(self(), {:run_ocr, job})
        Phoenix.PubSub.broadcast(DpulCollections.PubSub, "ocr", {:processing, job})
        {:noreply, state |> Map.put(:processing, job)}

      {:error, _} ->
        Process.send_after(self(), :check_for_updates, 1000)
        {:noreply, state}
    end
  end

  def handle_cast({:run_ocr, job}, state) do
    text = DpulCollections.Mocr.ocr(job)
    Phoenix.PubSub.broadcast(DpulCollections.PubSub, "ocr", {:processed, job, text})
    send(self(), :check_for_updates)
    {:noreply, state |> Map.put(:processing, nil)}
  end
end
