defmodule DpulCollectionsWeb.Live.Helpers do
  # Remove KV pairs with nil or empty string values
  def clean_params(params) do
    params
    |> Enum.reject(fn {_, v} -> v == "" end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
