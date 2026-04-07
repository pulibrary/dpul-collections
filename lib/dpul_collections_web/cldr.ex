defmodule DpulCollectionsWeb.Cldr do
  @moduledoc """
  """
  use Cldr,
    # according to https://github.com/elixir-cldr/cldr/issues/42
    locales: ["en", "es", "pt"],
    gettext: MyPhoenixApp.Gettext,
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime, Cldr.LocaleDisplay]
end
