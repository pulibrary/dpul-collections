defmodule DpulCollectionsWeb.Live.Helpers do
  # Remove KV pairs with nil or empty string values 
  # or with Keys in a remove_keys list
  # Also cleans nested maps.
  def clean_params(params = %{}, remove_keys \\ []) do
    params
    |> Enum.map(&clean_map_params(&1, remove_keys))
    # clean_map_params returns nil if it should be removed
    |> Enum.reject(fn x -> is_nil(x) end)
    |> Enum.into(%{})
  end

  # For k/v pairs
  # Ignore coverage, this is a header because of the remove_keys default
  # coveralls-ignore-next-line
  def clean_map_params(map_pair, remove_keys \\ [])
  def clean_map_params({_, ""}, _), do: nil
  def clean_map_params({_, nil}, _), do: nil
  def clean_map_params({k, v = %{}}, remove_keys), do: {k, clean_params(v, remove_keys)}

  def clean_map_params({k, v}, remove_keys) do
    case Enum.member?(remove_keys, k) do
      true ->
        nil

      _ ->
        {k, v}
    end
  end

  def obfuscate_item?(%{show_images: show_images, item: item}) do
    item.content_warning && !Enum.member?(show_images, item.id)
  end
end
