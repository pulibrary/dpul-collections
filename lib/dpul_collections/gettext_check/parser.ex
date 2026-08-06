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
      |> choose_tags([], %{last_tags: [], location_data: location_data})
    end)
  end

  # When there's nothing in the stack anymore, return the accumulator in
  # reverse (since everything was prepended)
  defp choose_tags([], acc, _context), do: acc |> Enum.reverse()
  # When a tag closes, remove it from last_tags.
  defp choose_tags(
         [{:close, _tag_type, _tag, _tag_metadata} | rest_tags],
         acc,
         context = %{last_tags: [_last_tag | tags]}
       ) do
    choose_tags(rest_tags, acc, Map.put(context, :last_tags, tags))
  end

  # When a tag opens, add it to last_tags. Process properties if necessary.
  defp choose_tags(
         [full_tag = {_tag_type, _content, _properties, %{tag_name: tag}} | rest_tags],
         acc,
         context
       ) do
    relevant_properties = select_relevant_properties(full_tag)

    choose_tags(
      rest_tags,
      choose_tags(relevant_properties, [], context) ++ acc,
      Map.put(context, :last_tags, [tag | context.last_tags])
    )
  end

  # If we're in a script, skip all content.
  defp choose_tags([_tag | rest_tags], acc, context = %{last_tags: ["script" | _]}) do
    choose_tags(rest_tags, acc, context)
  end

  defp choose_tags([tag | rest_tags], acc, context) do
    acc =
      if select_tag(tag) do
        [convert_tag(tag, context.location_data) | acc]
      else
        acc
      end

    choose_tags(rest_tags, acc, context)
  end

  defp select_relevant_properties({_tag_type, _tag_text, child_properties, _location_data})
       when is_list(child_properties) do
    selected_properties =
      child_properties
      |> Enum.filter(fn {property_name, _content, _location} ->
        property_name in ["aria-label", "label"]
      end)
      |> Enum.map(fn {_property_name, {type, sub_content, _sub_location}, location} ->
        {type, sub_content, location}
      end)

    selected_properties
  end

  defp select_relevant_properties(_parent_tag), do: []

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

  # No comments
  defp select_tag({:text, _, %{context: [:comment_start | _]}}), do: false

  defp select_tag({:text, content, _bla}) do
    case String.trim(content) |> String.replace(~r/[^0-9a-z ]/i, "") do
      "" -> false
      "nbsp" -> false
      # Anything that has alphanumeric characters is probably bad.
      _ -> true
    end
  end

  defp select_tag({:string, content, _}) do
    select_tag({:text, content, nil})
  end

  # If it starts with a quotation, it's a string, not okay.
  defp select_tag({:expr, "\"" <> _rest, _}) do
    true
  end

  defp select_tag({:expr, _content, _}), do: false

  defp select_tag(_node) do
    false
  end

  defp get_sigil_h(ast) do
    Macro.postwalk(ast, [], &traverse/2)
  end

  defp traverse(node = {:sigil_H, _location, _content}, acc) do
    {node, [node | acc]}
  end

  defp traverse(node, acc), do: {node, acc}
end
