defmodule DpulCollections.ImageSearchTest do
  use DpulCollections.DataCase
  alias DpulCollections.ImageSearch

  describe ".download_model!" do
    test "downloads the model" do
      assert ImageSearch.download_model! == {:ok, "#{File.cwd!()}/tmp/models/image_model.onnx"}
      assert ImageSearch.download_model!(:text) == {:ok, "#{File.cwd!()}/tmp/models/text_model.onnx"}
    end
  end

  describe ".image_embedding" do
    test "returns an embedding for an image URL" do
      image_url = "https://iiif-cloud.princeton.edu/iiif/2/df%2Fa7%2F5b%2Fdfa75b417f8d49739e24653ed1a87297%2Fintermediate_file/full/!1024,1024/0/default.jpg"
      output = ImageSearch.image_embedding(image_url)
      assert output.shape == {768}
    end
  end

  describe ".text_embedding" do
    test "returns an embedding for text" do
      output = ImageSearch.text_embedding("Cute animals")
      assert output.shape == {768}
    end
  end

  describe "comparing text/image embeddings" do
    test "can find similarity" do
      image_url = "https://iiif-cloud.princeton.edu/iiif/2/df%2Fa7%2F5b%2Fdfa75b417f8d49739e24653ed1a87297%2Fintermediate_file/full/!512,512/0/default.jpg"

      image_embedding = ImageSearch.image_embedding(image_url)
      text_embedding = ImageSearch.text_embedding("Realistic pictures of cityscapes")
      text_embedding_2 = ImageSearch.text_embedding("cute animals")
      text_embedding_3 = ImageSearch.text_embedding("two rabbits and one is holding a gun")
      text_embedding_4 = ImageSearch.text_embedding("a big man")
      text_embedding_5 = ImageSearch.text_embedding("cartoon representation of a gun")
      values = Scholar.Metrics.Distance.pairwise_cosine(Nx.stack([image_embedding]), Nx.stack([text_embedding, text_embedding_2, text_embedding_3, text_embedding_4, text_embedding_5])) |> Nx.take(0) |> then(&Nx.subtract(Nx.tensor(1), &1)) |> Nx.to_list

      assert Enum.at(values, 0) < Enum.at(values, 1)
      assert Enum.at(values, 0) < Enum.at(values, 2)
      assert Enum.at(values, 2) > Enum.at(values, 1)
      assert Enum.at(values, 3) < Enum.at(values, 2)
      assert Enum.at(values, 3) < Enum.at(values, 1)
      assert Enum.at(values, 3) < Enum.at(values, 4)
    end
  end
end
