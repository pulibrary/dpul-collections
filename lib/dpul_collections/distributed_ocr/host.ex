defmodule DpulCollections.DistributedOcr.Host do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{queue: [], done: %{}}}
  end

  def ocr_manifest(manifest) do
    GenServer.call(__MODULE__, {:ocr_manifest, manifest})
  end

  def fetch_job() do
    GenServer.call(__MODULE__, {:fetch_job})
  end

  def handle_call({:ocr_manifest, manifest}, _from, state) do
    %{body: manifest_content} = Req.get!(manifest)
    {:reply, {:ok, nil}, state |> Map.put(:queue, state.queue ++ ocr_pages(manifest_content))}
  end

  def handle_call({:fetch_job}, _from, state = %{queue: [first_job | rest_jobs]}) do
    state =
      state
      |> Map.put(:queue, rest_jobs)

    {:reply, {:ok, first_job}, state}
  end

  def handle_call({:fetch_job}, _from, state) do
    {:reply, {:error, :queue_empty}, state}
  end

  defp ocr_pages(manifest_content) when is_binary(manifest_content) do
    manifest_content
    |> dbg
    |> JSON.decode!()
    |> ocr_pages()
  end

  defp ocr_pages(%{"sequences" => [%{"canvases" => canvases} | _]}) do
    canvases
    |> Enum.flat_map(&Map.get(&1, "images"))
    |> Enum.map(&Map.get(&1, "resource"))
    |> Enum.map(&Map.get(&1, "service"))
    |> Enum.map(&Map.get(&1, "@id"))
    |> Enum.map(fn id -> "#{id}/full/1000,/0/default.jpg" end)
  end
end
