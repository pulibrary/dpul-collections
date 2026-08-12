defmodule DpulCollectionsWeb.Live.Helpers do
  use DpulCollectionsWeb, :verified_routes

  # Build a search URL with escaped square brackets.
  # Fixes errors copy and pasting search URLs as well as conforms to URI spec.
  # See: https://datatracker.ietf.org/doc/html/rfc3986#section-3.2.2
  def search_path(params) do
    ~p"/search?#{params}" |> encode_query_brackets()
  end

  defp encode_query_brackets(url) do
    String.replace(url, ["[", "]"], &bracket_escape/1)
  end

  defp bracket_escape("["), do: "%5B"
  defp bracket_escape("]"), do: "%5D"

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

  def truncate(text, max_length, omission \\ "...")

  def truncate(nil, _, _), do: nil

  def truncate(text, max_length, omission) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length - String.length(omission)) <> omission
    else
      text
    end
  end
end
