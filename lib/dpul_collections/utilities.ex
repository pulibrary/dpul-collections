defmodule DpulCollections.Utilities do
  def stringify_map_keys(map) do
    for {key, val} <- map, into: %{} do
      {to_string(key), val}
    end
  end

  # Extract an id string from a value map.
  # Exclude values that have more than one key. These are field like
  # pending_upload which should not be extracted a related resources.
  def extract_ids_from_value(value = %{"id" => id}) when map_size(value) == 1, do: id

  def extract_ids_from_value(_), do: nil
end
