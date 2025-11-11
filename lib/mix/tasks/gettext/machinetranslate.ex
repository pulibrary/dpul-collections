defmodule Mix.Tasks.Gettext.Machinetranslate do
  @moduledoc "Translates a given locale with google translate: `mix gettext.machinetranslate es`"
  use Mix.Task

  @impl Mix.Task
  def run([language_code]) do
    IO.puts("Translating from English to #{language_code}...")
    DpulCollections.Translator.translate_locale_file(language_code)
    IO.puts("Translated.")
  end
end
