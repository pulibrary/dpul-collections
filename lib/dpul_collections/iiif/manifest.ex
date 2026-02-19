defmodule DpulCollections.IIIF.Manifest do
  defstruct [:id, :label, :canvases]

  defmodule Canvas do
    defstruct [:id, :label, :image_url, :thumbnail_url, :width, :height]
  end

  def fetch(url) do
    {:ok, parse(Req.get!(url).body)}
  end

  def parse(manifest) do
    %__MODULE__{
      id: manifest["@id"],
      label: manifest["label"],
      canvases: parse_canvases(manifest)
    }
  end

  defp parse_canvases(%{"sequences" => [sequence | _]}) do
    sequence["canvases"] |> Enum.map(&parse_canvas/1)
  end

  defp parse_canvases(_), do: []

  defp parse_canvas(canvas) do
    service_url = get_image_service(canvas)

    %Canvas{
      id: canvas["@id"],
      label: canvas["label"],
      image_url: service_url,
      thumbnail_url: "#{service_url}/full/!150,200/0/default.jpg",
      width: canvas["width"],
      height: canvas["height"]
    }
  end

  defp get_image_service(canvas) do
    [image | _] = canvas["images"]
    image["resource"]["service"]["@id"]
  end

  def image_url(%Canvas{image_url: url}) do
    "#{url}/full/!1200,1600/0/default.jpg"
  end
end
