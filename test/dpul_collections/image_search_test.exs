defmodule DpulCollections.ImageSearchTest do
  use DpulCollections.DataCase
  alias DpulCollections.ImageSearch

  describe ".download_model!" do
    test "downloads the model" do
      assert ImageSearch.download_model! == {:ok, "#{File.cwd!()}/tmp/models/image_model.onnx"}
    end
  end

  describe ".image_embedding" do
    test "returns an embedding for an image URL" do
      image_url = "https://iiif-cloud.princeton.edu/iiif/2/df%2Fa7%2F5b%2Fdfa75b417f8d49739e24653ed1a87297%2Fintermediate_file/full/!1024,1024/0/default.jpg"
      output = ImageSearch.image_embedding(image_url)
      assert output.shape == {1152}
    end
  end
end
