defmodule Mix.Tasks.Model.Download do
  alias DpulCollections.Classifier.Serving
  @model DpulCollections.Classifier.Serving.model()
  @model_revision DpulCollections.Classifier.Serving.model_revision()
  @moduledoc "Download and cache necessary models from huggingface."
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    cache_dir = "#{:code.priv_dir(:dpul_collections)}/models"
    # Download Tokenizer
    if !File.exists?(Serving.tokenizer_path()) do
      Mix.shell().info("Downloading #{@model} revision #{@model_revision} tokenizer..")

      {:ok, response} =
        Tokenizers.HTTPClient.request(
          base_url: "https://huggingface.co",
          url: "/#{@model}/resolve/#{@model_revision}/tokenizer.json",
          method: :get
        )

      File.mkdir_p!(Path.dirname(Serving.tokenizer_path()))
      File.write!(Serving.tokenizer_path(), response.body)
    end

    if !File.exists?(Serving.model_path()) do
      Mix.shell().info("Downloading #{@model} revision #{@model_revision} ONNX model..")
      # Download Model
      {:ok, response} =
        Tokenizers.HTTPClient.request(
          base_url: "https://huggingface.co",
          url: "/#{@model}/resolve/#{@model_revision}/model.onnx",
          method: :get
        )

      File.mkdir_p!(Path.dirname(Serving.model_path()))
      File.write!(Serving.model_path(), response.body)
    end
  end
end
