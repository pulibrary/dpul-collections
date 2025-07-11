defmodule DpulCollections.Utilities do
  def stringify_map_keys(map) do
    for {key, val} <- map, into: %{} do
      {to_string(key), val}
    end
  end
end
