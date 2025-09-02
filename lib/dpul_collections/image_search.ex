defmodule DpulCollections.ImageSearch do
  @model_url "https://huggingface.co/Xenova/siglip-base-patch16-512/resolve/main/onnx/vision_model_uint8.onnx?download=true"
  @text_model_url "https://huggingface.co/Xenova/siglip-base-patch16-512/resolve/main/onnx/text_model_uint8.onnx?download=true"
  def download_model!() do
    File.mkdir_p!(Path.dirname(model_path()))

    case Req.get(@model_url, raw: true, into: File.stream!(model_path(), [:write])) do
      {:ok, _response} -> {:ok, model_path()}
      {:error, reason} -> {:error, "Failed to download file: #{inspect(reason)}"}
    end
  end

  def download_model!(:text) do
    File.mkdir_p!(Path.dirname(text_model_path()))

    case Req.get(@text_model_url, raw: true, into: File.stream!(text_model_path(), [:write])) do
      {:ok, _response} -> {:ok, text_model_path()}
      {:error, reason} -> {:error, "Failed to download file: #{inspect(reason)}"}
    end
  end

  def model_path, do: "#{File.cwd!()}/tmp/models/image_model.onnx"
  def text_model_path, do: "#{File.cwd!()}/tmp/models/text_model.onnx"

  def image_embedding(image_url) when is_binary(image_url) do
    model = load_model()
    %{status: 200, body: image_body} = Req.get!(image_url)
    {:ok, image} = Image.from_binary(image_body)


    # SIGLIP 2 normalizes by 0.5 across all three channels for both mean and
    # standard deviation.
    normalization_tensor = Nx.tensor([0.5, 0.5, 0.5])
    # A bunch of this is interpreted from
    # https://hexdocs.pm/image/segment_anything.html and modified for SIGLIP2.
    image_tensor =
      image
      |> Image.thumbnail!(512, fit: :contain)
      |> Image.to_nx!()
      |> Nx.as_type(:f32)
      |> NxImage.normalize(normalization_tensor, normalization_tensor)
      |> Nx.tensor(names: [:height, :width, :bands])
      |> Nx.transpose(axes: [:bands, :height, :width])

    model |> dbg

    input_tensor = image_tensor |> Nx.broadcast({1, 3, 512, 512})
    { _, embedding } = Ortex.run(model, input_tensor)
    embedding[0]
  end

  def text_embedding(text) do
    model = load_text_model()
    {:ok, tokenizer} = Tokenizers.Tokenizer.from_pretrained("Xenova/siglip-base-patch16-512")
    {:ok, [encoding]} = Tokenizers.Tokenizer.encode_batch(tokenizer, [text])
    input_ids = Tokenizers.Encoding.get_ids(encoding) |> Nx.tensor(type: :s64)
    {_, embedding} = Ortex.run(model, input_ids |> Nx.broadcast({1, 3}))
    embedding[0]
  end

  def load_model do
    Ortex.load(model_path())
  end

  def load_text_model() do
    Ortex.load(text_model_path())
  end
end
