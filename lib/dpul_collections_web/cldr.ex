defmodule DpulCollectionsWeb.Cldr do
  @moduledoc """
  """
  use Cldr,
    locales: ["en", "es", "pt"],
    gettext: MyPhoenixApp.Gettext,
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime, Cldr.LocaleDisplay]
end
