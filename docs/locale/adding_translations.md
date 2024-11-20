# How to Add Localized Translations

1. Any strings that require translation should be added using `gettext("Hello")`
2. Generate translation templates containing placeholders for all strings wrapped with gettext() by running  `mix gettext.extract` to extract gettext() calls to .pot (Portable Object Template) files, which are the base for all translations. 
3. In the console, run `mix gettext.merge priv/gettext` to update all locale-specific .po (Portable Object) files so that they include this message ID. Entries in PO files contain translations for their specific locale.
4. Add translations into the non-English .po files found in `priv/gettext/`. For example, to add the Spanish translations, update the `msgstr` for each English word you want to translate.

_see https://hexdocs.pm/gettext/Gettext.html for additional details_

## Special Cases: LUX Components
There are a couple of "gotchas" to be aware of for any LUX components that require translations. LUX components used include the Header and Footer elements.  
_see: lib/dpul_collections_web/components/lux-components_

### Use Longform for Vue.js Bindings
Heex templates will error when binding attributes using shorthand that starts with a ":".

Don't do this:
`<lux-menu-bar :menu-items="..."/>`

Do this:
`<lux-menu-bar v-bind:menu-items="..."/>`

### When using gettext inside of a component attribute
Use curly braces to turn the entire attribute value into a string and do Elixir-style string interpolation:

```
<lux-menu-bar v-bind:menu-items={"[{name: '#{gettext("Language")}'}]"} />
```

