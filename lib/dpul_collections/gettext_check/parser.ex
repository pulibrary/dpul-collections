defmodule DpulCollections.GettextCheck.Parser do
  def missing_gettext(file_path) do
    {_ast, sigil_h_blocks} =
      file_path
      |> Path.expand()
      |> File.read!()
      |> Code.string_to_quoted(columns: true)
      |> get_sigil_h()

    sigil_h_blocks
    |> Enum.flat_map(fn {:sigil_H, location_data, [{:<<>>, _meta, [text]} | _]} ->
      parsed_html =
        text
        |> Phoenix.LiveView.TagEngine.Parser.tokenize(
          strip_eex_comments: true,
          tag_handler: Phoenix.LiveView.HTMLEngine
        )

      parsed_html
      |> Enum.filter(&select_tag/1)
      |> Enum.map(&convert_tag(&1, location_data))
    end)
  end

  defp convert_tag({:text, content, %{line_end: line_end}}, [_, {:line, parent_line}, _]) do
    %{
      text: String.trim(content),
      line: parent_line + line_end - 1
    }
  end

  defp select_tag({:text, content, _}) do
    case String.trim(content) do
      "" -> false
      # Skip HTML comments
      "<!--" <> _ -> false
      # Anything that has alphanumeric characters is probably bad.
      _ -> String.replace(content, ~r/[^0-9A-z ]/, "") |> String.trim() != ""
    end
  end

  defp select_tag(node) do
    dbg(node)
    false
  end

  defp get_sigil_h(ast) do
    {_ast, sigil_h_blocks} = Macro.postwalk(ast, [], &traverse/2)
  end

  defp traverse(node = {:sigil_H, _location, _content}, acc) do
    {node, [node | acc]}
  end

  defp traverse(node, acc), do: {node, acc}
end
