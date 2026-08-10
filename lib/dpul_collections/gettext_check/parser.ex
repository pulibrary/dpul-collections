defmodule DpulCollections.GettextCheck.Parser do
  @required_translation_properties ["aria-label", "label"]

  def missing_gettext(file_path) do
    # Convert the file to AST, then pull out the ~H sections to be parsed.
    {_ast, sigil_h_blocks} =
      file_path
      |> Path.expand()
      |> File.read!()
      |> Code.string_to_quoted(columns: true)
      |> get_sigil_h()

    sigil_h_blocks
    # text here is a bunch of HTML, everything in the sigil_H.
    |> Enum.flat_map(fn {:sigil_H, location_data, [{:<<>>, _meta, [text]} | _]} ->
      parsed_html =
        text
        |> Phoenix.LiveView.TagEngine.Parser.tokenize(
          strip_eex_comments: false,
          tag_handler: Phoenix.LiveView.HTMLEngine
        )

      parsed_html
      |> process_tags([], %{last_tags: [], location_data: location_data})
    end)
  end

  # Recursively iterates through the parsed tags and returns only the tags that are missing gettext.
  # Example input:
  # [
  #   {:text, "Hi everyone, this is missing a gettext!\n", %{line_end: 2, column_end: 1}},
  #   {:body_expr, "gettext(\"Not missing here though!\")", %{line: 2, column: 1}},
  #   {:text, "\n", %{line_end: 3, column_end: 1}},
  #   {:tag, "p", [], %{line: 3, column: 1, tag_name: "p", inner_location: {3, 4}}},
  #   {:text, "\n  This is missing gettext, but in a tag!\n", %{line_end: 5, column_end: 1}},
  #   {:close, :tag, "p", %{line: 5, column: 1, tag_name: "p", inner_location: {5, 1}}}
  #  ]
  # This is a recursive function so it can keep track of what tag content is in.
  #
  # Returns content like:
  #
  # [
  #   %{line: 4, text: "Hi everyone, this is missing a gettext!"},
  #   %{line: 7, text: "This is missing gettext, but in a tag!"},
  #   %{line: 14, text: "\"Not translated!\""},
  #   %{line: 18, text: "Not translated!"}
  # ]
  #
  # When there's nothing in the stack anymore, return the accumulator in
  # reverse (since everything was prepended)
  defp process_tags([], acc, _context), do: acc |> Enum.reverse()
  # When a tag closes, remove it from last_tags.
  defp process_tags(
         [{:close, _tag_type, _tag, _tag_metadata} | rest_tags],
         acc,
         context = %{last_tags: [_last_tag | tags]}
       ) do
    process_tags(rest_tags, acc, Map.put(context, :last_tags, tags))
  end

  # Handle skip-gettext-start/end
  defp process_tags(
         [{:body_expr, "#skip-gettext-start", _properties} | rest_tags],
         acc,
         context
       ) do
    process_tags(
      rest_tags,
      acc,
      Map.put(context, :last_tags, ["skip-gettext" | context.last_tags])
    )
  end

  defp process_tags(
         [{:body_expr, "#skip-gettext-end", _properties} | rest_tags],
         acc,
         context = %{last_tags: ["skip-gettext" | tags]}
       ) do
    process_tags(rest_tags, acc, Map.put(context, :last_tags, tags))
  end

  # If we're in a skip-gettext tag, skip all content.
  defp process_tags([_tag | rest_tags], acc, context = %{last_tags: ["skip-gettext" | _]}) do
    process_tags(rest_tags, acc, context)
  end

  # When a tag opens, add it to last_tags. Process properties if necessary.
  # We might want to process properties like aria-label or label.
  defp process_tags(
         [full_tag = {_tag_type, _content, _properties, %{tag_name: tag}} | rest_tags],
         acc,
         context
       ) do
    # Convert properties to tags so we can call process_tags on them.
    relevant_properties = convert_properties_to_tags(full_tag)

    process_tags(
      rest_tags,
      process_tags(relevant_properties, [], context) ++ acc,
      Map.put(context, :last_tags, [tag | context.last_tags])
    )
  end

  # If we're in a script tag, skip all content.
  defp process_tags([_tag | rest_tags], acc, context = %{last_tags: ["script" | _]}) do
    process_tags(rest_tags, acc, context)
  end

  defp process_tags([tag | rest_tags], acc, context) do
    acc =
      if tag_with_missing_gettext?(tag) do
        [convert_tag(tag, context.location_data) | acc]
      else
        acc
      end

    # Debug tip: If you're not getting the matches you expected to get, a |> dbg
    # here with an extra dbg(tag) might help figure out what's going on.

    process_tags(rest_tags, acc, context)
  end

  defp convert_properties_to_tags({_tag_type, _tag_text, child_properties, _location_data})
       when is_list(child_properties) do
    selected_properties =
      child_properties
      |> Enum.filter(fn {property_name, _content, _location} ->
        property_name in @required_translation_properties
      end)
      |> Enum.map(fn {_property_name, {type, sub_content, _sub_location}, location} ->
        {type, sub_content, location}
      end)

    selected_properties
  end

  defp convert_tag({:text, content, %{line_end: line_end}}, location_data) do
    parent_line = location_data[:line]

    %{
      text: String.trim(content),
      # For some reason to get an accurate line for text we have to subtract 1
      # from line_end.
      line: parent_line + line_end - 1
    }
  end

  defp convert_tag({property_tag_type, content, %{line: line}}, location_data)
       when property_tag_type in [:string, :expr] do
    # parent_line is the line number of the sigil_h block that had the original
    # HTML
    parent_line = location_data[:line]

    %{
      text: String.trim(content),
      line: parent_line + line
    }
  end

  # Comments don't need gettext.
  defp tag_with_missing_gettext?({:text, _, %{context: [:comment_start | _]}}), do: false

  defp tag_with_missing_gettext?({:text, content, _bla}) do
    case String.trim(content) |> String.replace(~r/[^0-9a-z ]/i, "") do
      "" -> false
      # We have some cases where we have &nbsp;, those are fine.
      "nbsp" -> false
      # Anything that has alphanumeric characters is probably bad.
      _ -> true
    end
  end

  # This comes back in label/aria-label, like
  # <p label="test"></p>
  defp tag_with_missing_gettext?({:string, content, _}) do
    tag_with_missing_gettext?({:text, content, nil})
  end

  # If it starts with a quotation, it's a string, not okay.
  # This only happens in properties like label/aria-label, for example
  # <p label={"bla"}></p>
  defp tag_with_missing_gettext?({:expr, "\"" <> _rest, _}) do
    true
  end

  # Assume if we're calling a function in a property, it's gettext.
  defp tag_with_missing_gettext?({:expr, _content, _}), do: false

  defp tag_with_missing_gettext?(_node) do
    false
  end

  # Got this from https://dorgan.ar/posts/2021/04/the_elixir_ast/
  defp get_sigil_h(ast) do
    Macro.postwalk(ast, [], &traverse/2)
  end

  defp traverse(node = {:sigil_H, _location, _content}, acc) do
    {node, [node | acc]}
  end

  defp traverse(node, acc), do: {node, acc}
end
