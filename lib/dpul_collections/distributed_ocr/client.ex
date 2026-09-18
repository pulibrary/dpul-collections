defmodule DpulCollections.DistributedOcr.Client do
  # Server long-polls a host, grabs a job, runs it through OCR, and posts it
  # back.
  alias DpulCollections.Mocr
  use GenServer
  require Logger

  @error_backoff_ms 5_000
  @receive_timeout 60_000

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :start_loop}}
  end

  @impl true
  def handle_continue(:start_loop, state) do
    send(self(), :poll)
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case claim_job() do
      {:job, job} ->
        GenServer.cast(self(), {:run_ocr, job})
        {:noreply, state}

      :empty ->
        # Another client beat us to the claim, long-poll again.
        send(self(), :poll)
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("OCR client claim failed: #{inspect(reason)}")
        Process.send_after(self(), :poll, @error_backoff_ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:run_ocr, job}, state) do
    mode = mode(job["mode"])
    Logger.info("OCR: working on #{describe(job)}")

    {duration_us, text} =
      :timer.tc(fn -> Mocr.ocr(job["image_url"], mode) end)

    ms = div(duration_us, 1000)
    # TODO: Wonder if I can do some sort of progress bar...?
    Logger.info("OCR: finished #{describe(job)} in #{ms}ms")
    post_result(job, text, ms)
    send(self(), :poll)
    {:noreply, state}
  end

  defp describe(job) do
    [job["manifest_label"], job["page_label"], job["image_url"]]
    |> Enum.find(&(&1 not in [nil, ""]))
  end

  defp claim_job do
    case Req.post(req(),
           url: "/api/ocr/jobs/claim",
           json: %{client_id: client_id()}
         ) do
      {:ok, %{status: 200, body: job}} -> {:job, job}
      {:ok, %{status: 204}} -> :empty
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post_result(job, text, duration_ms) do
    %{model: model, version: version} = Mocr.model_info()

    Req.post(req(),
      url: "/api/ocr/jobs/#{job["job_id"]}/result",
      json: %{
        client_id: client_id(),
        text: text,
        model: model,
        model_version: version,
        duration_ms: duration_ms
      }
    )
  end

  defp req do
    Req.new(
      base_url: config()[:server_url] || "http://localhost:4000",
      auth: {:bearer, config()[:token]},
      # Long polling, so let this take a long time.
      receive_timeout: @receive_timeout
    )
  end

  defp client_id do
    config()[:client_id] || default_client_id()
  end

  defp default_client_id do
    {:ok, name} = :inet.gethostname()
    to_string(name)
  end

  # Leaving it open so I can request :layout_all or anything else Dots supports.
  defp mode(nil), do: :ocr

  defp mode(mode) when is_binary(mode) do
    String.to_existing_atom(mode)
  rescue
    ArgumentError -> :ocr
  end

  defp config, do: Application.get_env(:dpul_collections, __MODULE__, [])
end
