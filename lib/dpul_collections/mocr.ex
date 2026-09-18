defmodule DpulCollections.Mocr do
  use GenServer
  alias DpulCollections.Mocr.Native

  @prompts %{
    layout_all: """
    Please output the layout information from the PDF image, including each layout element's bbox, its category, and the corresponding text content within the bbox.

    1. Bbox format: [x1, y1, x2, y2]

    2. Layout Categories: The possible categories are ['Caption', 'Footnote', 'Formula', 'List-item', 'Page-footer', 'Page-header', 'Picture', 'Section-header', 'Table', 'Text', 'Title'].

    3. Text Extraction & Formatting Rules:
        - Picture: For the 'Picture' category, the text field should be omitted.
        - Formula: Format its text as LaTeX.
        - Table: Format its text as HTML.
        - All Others (Text, Title, etc.): Format their text as Markdown.

    4. Constraints:
        - The output text must be the original text from the image, with no translation.
        - All layout elements must be sorted according to human reading order.

    5. Final Output: The entire output must be a single JSON object.
    """,
    layout_only:
      "Please output the layout information from this PDF image, including each layout's bbox and its category. The bbox should be in the format [x1, y1, x2, y2]. The layout categories for the PDF document include ['Caption', 'Footnote', 'Formula', 'List-item', 'Page-footer', 'Page-header', 'Picture', 'Section-header', 'Table', 'Text', 'Title']. Do not output the corresponding text. The layout result should be in JSON format.",
    ocr: "Extract the text content from this image.",
    grounding_ocr:
      "Extract text from the given bounding box on the image (format: [x1, y1, x2, y2]).\nBounding Box:\n",
    web_parsing: "Parsing the layout info of this webpage image with format json:\n",
    scene_spotting: "Detect and recognize the text in the image.",
    general: " "
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ocr(url, mode \\ :ocr) do
    GenServer.call(__MODULE__, {:ocr, url, mode}, :infinity)
  end

  def model_info do
    config = Application.fetch_env!(:dpul_collections, __MODULE__)

    %{
      model: "#{config[:repo]}/#{config[:model_file]}",
      version: config[:model_version]
    }
  end

  @impl true
  def init(_opts) do
    {:ok, %{model: nil}, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, state) do
    config = Application.fetch_env!(:dpul_collections, __MODULE__)
    model_path = download(config, config[:model_file])
    mmproj_path = download(config, config[:mmproj_file])
    model = Native.load(model_path, mmproj_path)
    {:noreply, %{state | model: model}}
  end

  @impl true
  def handle_call({:ocr, url, mode}, _from, %{model: model} = state) do
    config = Application.fetch_env!(:dpul_collections, __MODULE__)
    %{body: image} = Req.get!(url)
    text = Native.ocr(model, image, @prompts[mode], config[:n_ctx])
    {:reply, text, state}
  end

  defp download(config, file) do
    File.mkdir_p!(config[:cache_dir])
    path = Path.join(config[:cache_dir], file)

    unless File.exists?(path) do
      url = "https://huggingface.co/#{config[:repo]}/resolve/main/#{file}"
      Req.get!(url, into: File.stream!(path))
    end

    path
  end
end
