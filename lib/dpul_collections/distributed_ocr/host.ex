defmodule DpulCollections.DistributedOcr.Host do
  # This used to do all the work the controller does, now it's mostly just
  # keeping track of client state and handing out jobs. I think I could simplify this..
  # This whole thing is kinda like Broadway honestly, but over HTTP, I wonder if
  # that's worthwhile to think about.
  # Or Oban?
  use GenServer
  alias DpulCollections.DistributedOcr

  @lease_seconds 300
  @default_poll_ms 25_000
  @reap_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Enqueue every page.
  def ocr_manifest(manifest) do
    GenServer.call(__MODULE__, {:ocr_manifest, manifest})
  end

  def retry_page(image_url) do
    GenServer.call(__MODULE__, {:retry_page, image_url})
  end

  def retry_manifest(manifest_url) do
    GenServer.call(__MODULE__, {:retry_manifest, manifest_url})
  end

  # For the long-poll controller.
  # Honestly idk if this is right, I don't think I need a genserver for this
  # anymore.
  def claim_job(client_id) do
    GenServer.call(__MODULE__, {:claim, client_id}, poll_ms() + 5_000)
  end

  def complete_job(job_id, attrs) do
    GenServer.call(__MODULE__, {:complete, job_id, attrs})
  end

  @impl true
  def init(_opts) do
    schedule_reap()
    {:ok, %{waiters: []}}
  end

  @impl true
  def handle_call({:ocr_manifest, manifest}, _from, state) do
    case fetch_and_enqueue(manifest) do
      {:ok, count} ->
        broadcast(:clients_changed)
        {:reply, {:ok, count}, flush_waiters(state)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:retry_page, image_url}, _from, state) do
    {:ok, _} = DistributedOcr.retry_page(image_url)
    broadcast(:clients_changed)
    {:reply, :ok, flush_waiters(state)}
  end

  def handle_call({:retry_manifest, manifest_url}, _from, state) do
    {:ok, count} = DistributedOcr.retry_manifest(manifest_url)
    broadcast(:clients_changed)
    {:reply, {:ok, count}, flush_waiters(state)}
  end

  # When the controller says "gimme a job" it either does it, or puts them in a
  # waiting queue and will tell them when it's ready.
  def handle_call({:claim, client_id}, from, state) do
    case DistributedOcr.claim_next(client_id, @lease_seconds) do
      {:ok, job} ->
        mark_working(client_id, job)
        {:reply, {:ok, job}, state}

      :empty ->
        mark_idle(client_id)
        timer = Process.send_after(self(), {:waiter_timeout, from}, poll_ms())
        {:noreply, %{state | waiters: state.waiters ++ [{from, client_id, timer}]}}
    end
  end

  def handle_call({:complete, job_id, attrs}, _from, state) do
    {:ok, result} = DistributedOcr.complete(job_id, attrs)
    mark_idle(attrs[:client_id])
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_info({:waiter_timeout, from}, state) do
    case pop_waiter(state.waiters, from) do
      {nil, _waiters} ->
        {:noreply, state}

      {_waiter, waiters} ->
        GenServer.reply(from, {:error, :queue_empty})
        {:noreply, %{state | waiters: waiters}}
    end
  end

  # Requeue any jobs that clients took too long for.
  def handle_info(:reap, state) do
    DistributedOcr.requeue_expired()
    schedule_reap()
    {:noreply, flush_waiters(state)}
  end

  # Hand a job to each parked waiter until the queue or the waiters run out.
  defp flush_waiters(%{waiters: []} = state), do: state

  defp flush_waiters(%{waiters: [{from, client_id, timer} | rest]} = state) do
    case DistributedOcr.claim_next(client_id, @lease_seconds) do
      {:ok, job} ->
        Process.cancel_timer(timer)
        mark_working(client_id, job)
        GenServer.reply(from, {:ok, job})
        flush_waiters(%{state | waiters: rest})

      :empty ->
        state
    end
  end

  defp mark_working(client_id, job) do
    DistributedOcr.touch_client(client_id, %{
      status: "working",
      image_url: job.image_url,
      manifest_label: job.manifest_label,
      page_label: job.page_label
    })

    broadcast(:clients_changed)
  end

  defp mark_idle(client_id) do
    DistributedOcr.touch_client(client_id, %{status: "idle"})
    broadcast(:clients_changed)
  end

  defp pop_waiter(waiters, from) do
    case Enum.split_with(waiters, fn {waiter_from, _id, _timer} -> waiter_from == from end) do
      {[waiter], rest} -> {waiter, rest}
      {[], _} -> {nil, waiters}
    end
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(DpulCollections.PubSub, "ocr", message)
  end

  defp schedule_reap, do: Process.send_after(self(), :reap, @reap_ms)

  defp poll_ms do
    Application.get_env(:dpul_collections, __MODULE__, [])
    |> Keyword.get(:poll_ms, @default_poll_ms)
  end

  defp iiif_size do
    Application.get_env(:dpul_collections, __MODULE__, [])
    |> Keyword.get(:iiif_size, "1500,")
  end

  defp fetch_and_enqueue(manifest) do
    with {:ok, %{body: content}} <- Req.get(manifest),
         {manifest_label, pages} <- parse_manifest(content) do
      {:ok, DistributedOcr.enqueue_pages(manifest, manifest_label, pages)}
    else
      {:error, %{__exception__: true} = e} -> {:error, Exception.message(e)}
      _ -> {:error, "that doesn't look like a IIIF manifest"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp parse_manifest(content) when is_binary(content) do
    content |> JSON.decode!() |> parse_manifest()
  end

  defp parse_manifest(%{"sequences" => [%{"canvases" => canvases} | _]} = manifest) do
    {label(manifest["label"]), Enum.map(canvases, &page_from_canvas/1)}
  end

  defp page_from_canvas(canvas) do
    image_url =
      canvas
      |> Map.get("images", [])
      |> List.first(%{})
      |> get_in(["resource", "service", "@id"])
      # TODO: I wonder if I shouldn't store the size here, it makes it so if I
      # change the iiif_size I have to delete things before retrying.
      |> then(fn id -> "#{id}/full/#{iiif_size()}/0/default.jpg" end)

    %{image_url: image_url, page_label: label(canvas["label"])}
  end

  # IIIF labels can be a string or a list of strings.
  defp label([first | _]), do: label(first)
  defp label(label) when is_binary(label), do: label
  defp label(_), do: nil
end
