defmodule DpulCollectionsWeb.Live.Helpers do
  # Remove KV pairs with nil or empty string values 
  # or with Keys in a remove_keys list
  def clean_params(params, remove_keys \\ []) do
    params
    |> Enum.reject(fn {_, v} -> v == "" end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.reject(fn {k, _} -> Enum.member?(remove_keys, k) end)
    |> Enum.into(%{})
  end
end
