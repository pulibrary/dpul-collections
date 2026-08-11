defmodule Mix.Tasks.GettextCheck do
  @moduledoc "Mix task to check for LiveViews missing gettext calls"
  use Mix.Task

  @shortdoc "Output all views that have missing gettext."
  def run(_) do
    missing_gettext =
      "lib/dpul_collections_web/live/**/*.ex"
      |> Path.wildcard()
      |> Enum.reduce(%{}, fn file_path, acc ->
        missing = DpulCollections.GettextCheck.Parser.missing_gettext(file_path)

        case missing do
          [] -> acc
          _ -> Map.put(acc, file_path, missing)
        end
      end)

    if missing_gettext != %{} do
      IO.puts("Detected the following missing gettext strings:")
      IO.inspect(missing_gettext, syntax_colors: IO.ANSI.syntax_colors(), limit: :infinity)
      exit({:shutdown, 1})
    else
      IO.puts("No missing gettext calls detected!")
    end
  end
end
