defmodule DpulCollections.Ocr do
  use GenServer

  alias DpulCollections.Ocr.Native

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Download an image and return markdown."
  def ocr(url) do
    GenServer.call(__MODULE__, {:ocr, url}, :infinity)
  end

  @doc "Download an image and return markdown."
  def paddle_ocr(url) do
    GenServer.call(__MODULE__, {:paddle_ocr, url}, :infinity)
  end

  @doc "Download an image, classify parts of it into bounding boxes, then convert each part into markdown."
  def layout_ocr(url) do
    GenServer.call(__MODULE__, {:layout_ocr, url}, :infinity)
  end

  @doc "Like layout_ocr/1, but recognizes each region with PaddleOCR-VL instead of OvisOCR2."
  def paddle_layout_ocr(url) do
    GenServer.call(__MODULE__, {:paddle_layout_ocr, url}, :infinity)
  end

  @loc_run ~r/([\s\S]*?)((?:<\|LOC_\d+\|>)+)/
  @loc_token ~r/<\|LOC_(\d+)\|>/

  def parse_paddle_ocr(raw) when is_binary(raw) do
    @loc_run
    |> Regex.scan(raw, capture: :all_but_first)
    |> Enum.map(fn [text, locs] ->
      box =
        @loc_token
        |> Regex.scan(locs, capture: :all_but_first)
        |> Enum.map(fn [n] -> String.to_integer(n) end)
        |> Enum.chunk_every(2)
        |> Enum.map(fn [x, y] -> {x, y} end)

      %{text: String.trim(text), box: box}
    end)
  end

  @impl true
  def init(_opts) do
    # https://github.com/GreatV/oar-ocr/tree/main/oar-ocr-vl#installation
    # This says set OAR_VL_DTYPE for metal, so here we go.
    System.put_env("OAR_VL_DTYPE", System.get_env("OAR_VL_DTYPE") || "f16")
    {:ok, %{ocr: nil, layout: nil, paddle: nil}}
  end

  @impl true
  def handle_call({:ocr, url}, _from, state) do
    state = ensure_ocr(state)

    with_temp(url, fn path ->
      {:reply, Native.ocr_path(state.ocr, path, config(:max_new_tokens)), state}
    end)
  end

  @impl true
  def handle_call({:paddle_ocr, url}, _from, state) do
    state = ensure_paddle(state)

    with_temp(url, fn path ->
      result = state.paddle |> Native.paddle_ocr_path(path) |> parse_paddle_ocr()
      {:reply, result, state}
    end)
  end

  def handle_call({:layout_ocr, url}, _from, state) do
    state = state |> ensure_ocr() |> ensure_layout()

    with_temp(url, fn path ->
      {:reply, Native.layout_ocr_path(state.ocr, state.layout, path), state}
    end)
  end

  def handle_call({:paddle_layout_ocr, url}, _from, state) do
    state = state |> ensure_paddle() |> ensure_layout()

    with_temp(url, fn path ->
      {:reply, Native.layout_paddle_ocr_path(state.paddle, state.layout, path), state}
    end)
  end

  # Lazy-cache models, they're like over a gig.
  defp ensure_ocr(%{ocr: nil} = state), do: %{state | ocr: load(:model_id, &Native.load_model/2)}
  defp ensure_ocr(state), do: state

  defp ensure_layout(%{layout: nil} = state),
    do: %{state | layout: load(:layout_model_id, &Native.load_layout/2)}

  defp ensure_layout(state), do: state

  defp ensure_paddle(%{paddle: nil} = state),
    do: %{state | paddle: load(:paddle_model_id, &Native.load_paddle/2)}

  defp ensure_paddle(state), do: state

  defp load(id_key, loader) do
    {:ok, dir} = HfHub.Download.snapshot_download(repo_id: config(id_key))
    loader.(dir, config(:device))
  end

  defp with_temp(url, fun) do
    path = download_to_temp(url)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end

  # Get the image somewhere we can pass as a file path.
  defp download_to_temp(url) do
    ext = url |> URI.parse() |> Map.get(:path, "") |> to_string() |> Path.extname()
    path = Path.join(System.tmp_dir!(), "dpul_ocr_#{System.unique_integer([:positive])}#{ext}")
    Req.get!(url, into: File.stream!(path))
    path
  end

  defp config(key), do: Application.fetch_env!(:dpul_collections, __MODULE__)[key]
end
