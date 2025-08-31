defmodule DpulCollections.ImageSearch do
  @model_url "https://huggingface.co/onnx-community/siglip2-so400m-patch16-512-ONNX/resolve/main/onnx/vision_model_q4f16.onnx?download=true"
  def download_model!() do
    File.mkdir_p!(Path.dirname(model_path()))

    case Req.get(@model_url, raw: true, into: File.stream!(model_path(), [:write])) do
      {:ok, _response} -> {:ok, model_path()}
      {:error, reason} -> {:error, "Failed to download file: #{inspect(reason)}"}
    end
  end

  def model_path, do: "#{File.cwd!()}/tmp/models/image_model.onnx"

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
      |> Image.thumbnail!("512x512", crop: :attention)
      |> Image.to_nx!()
      |> Nx.as_type(:f32)
      |> NxImage.normalize(normalization_tensor, normalization_tensor)
      |> Nx.tensor(names: [:height, :width, :bands])
      |> Nx.transpose(axes: [:bands, :height, :width])

    input_tensor = image_tensor |> Nx.broadcast({1, 3, 512, 512})
    { _, embedding } = Ortex.run(model, input_tensor)
    embedding[0]
  end

  def load_model do
    Ortex.load(model_path())
  end
end
