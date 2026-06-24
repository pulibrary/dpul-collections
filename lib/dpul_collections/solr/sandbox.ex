defmodule DpulCollections.Solr.Sandbox do
  def allow(user_agent) do
    if key = key_for(user_agent) do
      Process.put(:solr_sandbox_key, key)
    end

    :ok
  end

  defp key_for(user_agent) when is_binary(user_agent) do
    case Phoenix.Ecto.SQL.Sandbox.decode_metadata(user_agent) do
      %{owner: owner} when is_pid(owner) -> owner_key(owner)
      _ -> nil
    end
  end

  defp key_for(_), do: nil

  defp owner_key(owner) do
    case Process.info(owner, :dictionary) do
      {:dictionary, dict} -> Keyword.get(dict, :solr_sandbox_key)
      _ -> nil
    end
  end
end
