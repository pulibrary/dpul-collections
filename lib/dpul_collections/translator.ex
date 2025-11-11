defmodule DpulCollections.Translator do
  def translate_locale_file(target_locale) do
    locale_file = "priv/gettext/#{target_locale}/LC_MESSAGES/default.po"
    parsed_po = Expo.PO.parse_file!(locale_file)

    # Find all the messages we need to translate - any that have a blank string
    # for a translation.
    strings_to_translate =
      parsed_po.messages
      # Filter out already translated messages.
      |> Enum.filter(fn %{msgstr: translated_message} -> translated_message == [""] end)
      |> Enum.flat_map(&Map.get(&1, :msgid))

    # Ask google translate to translate them.
    translations_map = translate(strings_to_translate, target_locale)

    # Apply the new translations - if there isn't a match, fall back to whatever
    # was there before so we don't re-translate things that already have
    # translations.
    new_messages =
      parsed_po.messages
      |> Enum.map(&apply_translations(&1, translations_map))

    parsed_po
    |> Map.put(:messages, new_messages)
    |> Expo.PO.compose()
    |> then(fn content -> File.write!(locale_file, content) end)
  end

  defp apply_translations(
         message = %{msgid: strings_to_translate, msgstr: existing_values},
         translation_map = %{}
       ) do
    existing_translations =
      strings_to_translate
      |> Enum.zip(existing_values)
      |> Enum.into(%{})

    translated_messages =
      strings_to_translate
      |> Enum.map(fn string ->
        Map.get(translation_map, string) || Map.get(existing_translations, string)
      end)

    cond do
      # We didn't do any translation, just return the message
      translated_messages == existing_values ->
        message
      # We translated, mark this message as machine generated, which means humans should
      # review it.
      true ->
        message
        |> Expo.Message.append_flag("machine-generated")
        |> Map.put(:msgstr, translated_messages)
    end
  end

  def translate([], _target_locale) do
    %{}
  end

  def translate(strings_to_translate, target_locale) when is_list(strings_to_translate) do
    translations =
      strings_to_translate
      |> Enum.chunk_every(10)
      |> Enum.flat_map(fn strings ->
        request = %GoogleApi.Translate.V3.Model.TranslateTextRequest{
          contents: strings,
          targetLanguageCode: target_locale,
          sourceLanguageCode: "en",
          model: "projects/pul-gcdc/locations/us-central1/models/general/translation-llm"
        }

        case GoogleApi.Translate.V3.Api.Projects.translate_projects_translate_text(
               connection(),
               "projects/pul-gcdc",
               body: request
             ) do
          {:error, _} ->
            raise "Failure during translation of #{strings}"

          {:ok, %{translations: translations = [%{translatedText: _translation} | _]}} ->
            translations
            |> Enum.map(&Map.get(&1, :translatedText))
        end
      end)

    Enum.zip(strings_to_translate, translations)
    |> Enum.into(%{})
  end

  defp connection() do
    %{token: token} = Goth.fetch!(DpulCollections.Goth)
    GoogleApi.Translate.V3.Connection.new(token)
  end
end
