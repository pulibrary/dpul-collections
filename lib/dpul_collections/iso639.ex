defmodule DpulCollections.ISO639 do
  # Pulled from https://raw.githubusercontent.com/haliaeetus/iso-639/46f4a3a39c68618671c7f101971f18c9e7ec07df/data/iso_639-2.json
  @language_data Application.app_dir(:dpul_collections, "priv/iso_639-2.json")
                 |> File.read!()
                 |> JSON.decode!()

  def label(code) do
    case Map.get(@language_data, code) do
      %{"en" => [label | _]} -> {:ok, label}
      _ -> {:error, :not_found}
    end
  end
end
