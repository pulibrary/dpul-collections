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
      |> Enum.flat_map(&expand_relevant_properties/1)
      |> Enum.filter(&select_tag/1)
      |> Enum.map(&convert_tag(&1, location_data))
    end)
  end

  defp expand_relevant_properties(
         parent_tag = {_tag_type, tag_text, child_properties, _location_data}
       )
       when is_list(child_properties) do
    selected_properties =
      child_properties
      |> Enum.filter(fn {property_name, content, location} ->
        property_name in ["aria-label", "label"]
      end)
      |> Enum.map(fn {property_name, {type, sub_content, _sub_location}, location} ->
        {type, sub_content, location}
      end)

    [parent_tag | selected_properties]
  end

  defp expand_relevant_properties(parent_tag), do: [parent_tag]

  defp convert_tag({:text, content, %{line_end: line_end}}, location_data) do
    parent_line = location_data[:line]

    %{
      text: String.trim(content),
      line: parent_line + line_end - 1
    }
  end

  defp convert_tag({property_tag_type, content, %{line: line}}, location_data)
       when property_tag_type in [:string, :expr] do
    parent_line = location_data[:line]

    %{
      text: String.trim(content),
      line: parent_line + line
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

  defp select_tag({:string, content, _}) do
    select_tag({:text, content, nil})
  end

  defp select_tag({:expr, content, _}) do
    !is_gettext?(content)
  end

  defp select_tag(node) do
    false
  end

  defp is_gettext?("gettext(" <> _string), do: true
  defp is_gettext?(_), do: false

  defp get_sigil_h(ast) do
    Macro.postwalk(ast, [], &traverse/2)
  end

  defp traverse(node = {:sigil_H, _location, _content}, acc) do
    {node, [node | acc]}
  end

  defp traverse(node, acc), do: {node, acc}
end
