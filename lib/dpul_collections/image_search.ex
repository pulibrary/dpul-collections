defmodule DpulCollections.ImageSearch do
  @model_url "https://huggingface.co/nomic-ai/nomic-embed-vision-v1.5/resolve/main/onnx/model_uint8.onnx?download=true"
  @text_model_url "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5/resolve/main/onnx/model_uint8.onnx?download=true"
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
      |> Image.thumbnail!(224)
      |> Image.embed!(224, 224)
      |> Image.to_nx!()
      |> Nx.as_type(:f32)
      # |> NxImage.normalize(normalization_tensor, normalization_tensor)
      |> Nx.tensor(names: [:height, :width, :bands])
      |> Nx.transpose(axes: [:bands, :height, :width])

    input_tensor = image_tensor |> Nx.broadcast({1, 3, 224, 224})
    {last_hidden_state, _} = Ortex.run(model, input_tensor) |> Nx.backend_transfer(Nx.default_backend())
    classification_tokens = last_hidden_state[[.., 0]]
    classification_tokens[0]
  end

  def text_embedding(text) do
    model = load_text_model()
    {:ok, tokenizer} = Tokenizers.Tokenizer.from_pretrained("nomic-ai/nomic-embed-text-v1.5")
    {:ok, [encoding]} = Tokenizers.Tokenizer.encode_batch(tokenizer, [text])
    input_ids = Tokenizers.Encoding.get_ids(encoding) |> Nx.tensor(type: :s64)
    input_type_ids = Tokenizers.Encoding.get_type_ids(encoding) |> Nx.tensor(type: :s64)
    attention_mask = Tokenizers.Encoding.get_attention_mask(encoding) |> Nx.tensor(type: :s64)

    {embedding} =
      Ortex.run(
        model,
        {Nx.stack([input_ids]), Nx.stack([input_type_ids]), Nx.stack([attention_mask])}
      )
      |> Nx.backend_transfer(Nx.default_backend())

    # Mean pool
    attention_mask_expanded = Nx.new_axis(Nx.stack([attention_mask]), -1)

    pooled =
      embedding
      |> Nx.multiply(attention_mask_expanded)
      |> Nx.sum(axes: [1])
      |> Nx.divide(Nx.sum(attention_mask_expanded, axes: [1]))

    pooled[0]
  end

  def load_model do
    Ortex.load(model_path())
  end

  def load_text_model() do
    Ortex.load(text_model_path())
  end
end
