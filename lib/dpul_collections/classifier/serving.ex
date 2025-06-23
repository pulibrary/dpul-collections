defmodule DpulCollections.Classifier.Serving do
  @model "janni-t/qwen3-embedding-0.6b-int8-tei-onnx"
  @padding_groups [8, 16, 32, 64, 128, 256, 512]

  def serving() do
    model = Ortex.load("./models/qwen3_int8.onnx")

    {:ok, tokenizer} =
      Tokenizers.Tokenizer.from_pretrained("janni-t/qwen3-embedding-0.6b-int8-tei-onnx")

    tokenizer =
      Tokenizers.Tokenizer.set_padding(tokenizer, direction: :left)
      |> Tokenizers.Tokenizer.set_truncation(max_length: 512)

    Nx.Serving.new(Ortex.Serving, model)
    |> Nx.Serving.client_preprocessing(&build_embedding_inputs(&1, tokenizer))
    |> Nx.Serving.client_postprocessing(&last_token_pooling/2)
  end

  def last_token_pooling({{embeddings}, _meta}, client_info) do
    {input_size, token_embedding_count, embedding_dimension} = Nx.shape(embeddings)

    embeddings
    |> Nx.slice_along_axis(token_embedding_count, 1, axis: 1)
    |> Nx.reshape({input_size, embedding_dimension})
  end

  def build_embedding_inputs(inputs, tokenizer) do
    {:ok, encodings} = Tokenizers.Tokenizer.encode_batch(tokenizer, inputs)
    # For batching we need to have consistent steps. Max size is 8192. They're
    # all padded, so get the minimum group
    first_encoding_length = hd(encodings) |> Tokenizers.Encoding.get_length()
    padding_size = Enum.find(@padding_groups, fn x -> x >= first_encoding_length end)

    encodings =
      Enum.map(encodings, fn x -> Tokenizers.Encoding.pad(x, padding_size, direction: :left) end)

    input_ids = for i <- encodings, do: Tokenizers.Encoding.get_ids(i)
    input_mask = for i <- encodings, do: Tokenizers.Encoding.get_attention_mask(i)

    inputs =
      Enum.zip_with(input_ids, input_mask, fn a, b ->
        {Nx.tensor(a, type: :s64), Nx.tensor(b, type: :s64)}
      end)
      |> Nx.Batch.stack()
      |> Nx.Batch.key(padding_size)

    {inputs, %{}}
  end
end
