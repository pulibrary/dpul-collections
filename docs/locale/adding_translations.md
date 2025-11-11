# Localization (aka, Internationalization)

All strings that require translation should be added using `gettext("Hello")`

## How to Add or Update Localized Translations

1. `mix clean` will clear out the local build directories, where gettext tracks its work.
1. `mix gettext.extract` will generate the .pot (Portable Object Template) files which contain all the strings and are used to create and update the language-specific .po translation files. 
3. `mix gettext.merge priv/gettext` will update all locale-specific .po (Portable Object) files so that they include every message ID in the .pot files.
4. Finally, update the .po files found in `priv/gettext/`.
   a. search for ", fuzzy" to find strings that gettext did a best effort match on, and edit them. Then delete the ", fuzzy" so that we know they have been confirmed.
   b. search for "" to find newly-added strings that need to be translated

_see https://hexdocs.pm/gettext/Gettext.html for additional details_

## Adding a new language

The relative time wording used in the recently updated content area is implemented via Cldr, which provides its own translations. When we add new languages we should ensure the translations are working from upstream.

To add a new language:

1. Find the new locale code (for example, `el` for greek)
1. `mkdir -p priv/gettext/el/LC_MESSAGES`
1. `mix gettext.merge priv/gettext`
1. `mix gettext.machinetranslate el`
1. Add the new language to `lib/dpul_collections_web/components/header_component.md`
1. Add the new locale to gettext config in `config/config.exs` - search for `locales:`
1. Add the new locale to DpulCollectionsWeb.Cldr
1. Create a PR - in the future we'll have a human review process.
