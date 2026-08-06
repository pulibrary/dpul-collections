defmodule Mix.Tasks.GettextCheck do
  @moduledoc "Mix task to check for LiveViews missing gettext calls"
  use Mix.Task

  @shortdoc "Output all views that have missing gettext."
  def run(_) do
    [
      "lib/dpul_collections_web/live/home_live.ex",
      "lib/dpul_collections_web/live/collections_live.ex"
    ]
    |> Enum.reduce(%{}, fn file_path, acc ->
      missing = DpulCollections.GettextCheck.Parser.missing_gettext(file_path)

      case missing do
        [] -> acc
        _ -> Map.put(acc, file_path, missing)
      end
    end)
    |> dbg()
  end
end
