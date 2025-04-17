# Localization (aka, Internationalization)

## How to Add Localized Translations

1. Any strings that require translation should be added using `gettext("Hello")`
2. Generate translation templates containing placeholders for all strings wrapped with gettext() by running  `mix gettext.extract` to extract gettext() calls to .pot (Portable Object Template) files, which are the base for all translations. 
3. In the console, run `mix gettext.merge priv/gettext` to update all locale-specific .po (Portable Object) files so that they include this message ID. Entries in PO files contain translations for their specific locale.
4. Add translations into the non-English .po files found in `priv/gettext/`. For example, to add the Spanish translations, update the `msgstr` for each English word you want to translate.

## How to Edit Localized Translations
If you edit the original string ids, simply run mix gettext.extract again. Then, the next mix gettext.merge can do fuzzy matching. So, if you change "Hello world" to "Hello world!", Gettext will see that the new message ID is similar to an existing msgid, and will do two things:

    1. It will update the msgid in all .po files to match the new text.

    2. It will mark those entries as "fuzzy"; this hints that a (probably human) translator should check whether the Italian translation of this string needs an update.

_see https://hexdocs.pm/gettext/Gettext.html for additional details_

## Adding a new language

The relative time wording used in the recently added content area is implemented via Cldr, which provides its own translations. When we add new languages we should ensure the translationsa are working from upstream.
